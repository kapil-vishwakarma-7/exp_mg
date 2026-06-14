import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/sms_logger.dart';

// ── Request / response models ─────────────────────────────────────────────────

/// One message sent to the AI parser API.
class AiSmsInput {
  const AiSmsInput({required this.sender, required this.text});

  final String sender;
  final String text;

  Map<String, String> toJson() => <String, String>{
        'sender': sender,
        'text': text,
      };
}

/// Parsed result returned by the AI parser for one message.
///
/// All fields are nullable — the API may omit any for non-transactional
/// messages or when extraction fails. Callers must treat every field as
/// optional and fall back to the rule-based parser when they are absent.
class AiParsedResult {
  const AiParsedResult({
    required this.originalText,
    this.isTransaction,
    this.amount,
    this.type,
    this.merchant,
    this.category,
    this.account,
    this.balance,
    this.transactionDate,
  });

  /// Raw SMS body — used to correlate result → original SmsMessage.
  final String originalText;

  final bool? isTransaction;
  final double? amount;

  /// 'debit' | 'credit' | null
  final String? type;
  final String? merchant;
  final String? category;
  final String? account;
  final double? balance;
  final DateTime? transactionDate;

  /// True when the result has everything needed to build a ParsedTransaction.
  bool get looksLikeTransaction =>
      (isTransaction ?? false) &&
      amount != null &&
      amount! > 0 &&
      type != null;

  factory AiParsedResult.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return AiParsedResult(
      // API may return 'text', 'original_text', or 'message' for the key.
      originalText: (json['text'] as String?) ??
          (json['original_text'] as String?) ??
          (json['message'] as String?) ??
          '',
      isTransaction: json['is_transaction'] as bool?,
      amount: parseDouble(json['amount']),
      type: json['type'] as String?,
      merchant: json['merchant'] as String?,
      category: json['category'] as String?,
      account: json['account'] as String?,
      balance: parseDouble(json['balance']),
      transactionDate: parseDate(json['transaction_date']),
    );
  }

  @override
  String toString() =>
      'AiParsedResult(isTransaction=$isTransaction, '
      'amount=$amount, type=$type, merchant=$merchant)';
}

/// Result of a single batch call.
class BatchCallResult {
  const BatchCallResult({required this.results, this.error});

  final List<AiParsedResult> results;

  /// Non-null when the batch failed after all retries.
  final String? error;

  bool get succeeded => error == null;
}

// ── Client ────────────────────────────────────────────────────────────────────

/// Pure HTTP wrapper around the AI SMS parser API.
///
/// Responsibilities:
///   - Serialise a batch of [AiSmsInput] to JSON
///   - POST to the endpoint with timeout
///   - Deserialise the response into [AiParsedResult] list
///   - Retry up to [maxRetries] times with exponential back-off
///
/// Contains no business logic — inject a different implementation to swap
/// the AI provider without touching the pipeline layer.
class AiSmsApiClient {
  AiSmsApiClient({
    http.Client? httpClient,
    this.maxRetries = 2,
    this.timeout = const Duration(seconds: 10),
  }) : _client = httpClient ?? http.Client();

  static const String _endpoint =
      'https://kimigd2ong.execute-api.us-east-1.amazonaws.com'
      '/expensetracker/sms-parser';

  final http.Client _client;
  final int maxRetries;
  final Duration timeout;

  /// Sends one batch (≤ 25 messages) to the API.
  ///
  /// Never throws. On persistent failure returns a [BatchCallResult] with a
  /// non-null [BatchCallResult.error] so the pipeline can fall back gracefully.
  Future<BatchCallResult> callBatch(List<AiSmsInput> batch) async {
    assert(batch.isNotEmpty);
    assert(batch.length <= 25, 'API accepts max 25 messages per request');

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(seconds: attempt));
          SmsLogger.sms(
            '[AI] Retry attempt $attempt for batch of ${batch.length}',
          );
        }

        final requestBody = jsonEncode(<String, dynamic>{
          'messages': batch.map((m) => m.toJson()).toList(),
        });

        // ── REQUEST LOG ───────────────────────────────────────────────────
        SmsLogger.sms(
          '[AI][REQ] attempt=${attempt + 1}/${maxRetries + 1} '
          'messages=${batch.length} endpoint=$_endpoint',
        );
        SmsLogger.sms('[AI][REQ] body=$requestBody');

        final stopwatch = Stopwatch()..start();

        final response = await _client
            .post(
              Uri.parse(_endpoint),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: requestBody,
            )
            .timeout(timeout);

        stopwatch.stop();

        // ── RESPONSE LOG ──────────────────────────────────────────────────
        SmsLogger.sms(
          '[AI][RES] status=${response.statusCode} '
          'latency=${stopwatch.elapsedMilliseconds}ms '
          'bodyLength=${response.body.length}',
        );
        SmsLogger.sms('[AI][RES] body=${response.body}');

        if (response.statusCode == 200) {
          final results = _parseResponse(response.body);

          // ── PARSED RESULTS SUMMARY ────────────────────────────────────
          SmsLogger.sms(
            '[AI][RES] parsed: ${results.length} result(s) '
            'from ${batch.length} message(s)',
          );
          for (var i = 0; i < results.length; i++) {
            final r = results[i];
            SmsLogger.sms(
              '[AI][RES] [$i] isTransaction=${r.isTransaction} '
              'amount=${r.amount} type=${r.type} merchant=${r.merchant} '
              'category=${r.category}',
            );
          }

          return BatchCallResult(results: results);
        }

        SmsLogger.sms(
          '[AI][RES] Non-200 on attempt $attempt — '
          'HTTP ${response.statusCode}',
        );

        // 4xx is not retryable.
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return BatchCallResult(
            results: const <AiParsedResult>[],
            error: 'HTTP ${response.statusCode}',
          );
        }
      } on TimeoutException {
        SmsLogger.sms(
          '[AI][ERR] Timeout after ${timeout.inSeconds}s '
          'on attempt $attempt',
        );
      } on SocketException catch (e) {
        SmsLogger.sms('[AI][ERR] Network error on attempt $attempt: $e');
      } on FormatException catch (e) {
        SmsLogger.sms('[AI][ERR] Invalid JSON response: $e');
        return BatchCallResult(
          results: const <AiParsedResult>[],
          error: 'Invalid JSON: $e',
        );
      } catch (e) {
        SmsLogger.sms('[AI][ERR] Unexpected error on attempt $attempt: $e');
      }
    }

    SmsLogger.sms(
      '[AI][ERR] All ${maxRetries + 1} attempts failed '
      'for batch of ${batch.length} messages',
    );
    return BatchCallResult(
      results: const <AiParsedResult>[],
      error: 'Failed after $maxRetries retries',
    );
  }

  List<AiParsedResult> _parseResponse(String body) {
    try {
      final dynamic decoded = jsonDecode(body);

      // Accept { "results": [...] }  OR  bare array  [ ... ]
      final List<dynamic> items;
      if (decoded is Map && decoded['results'] is List) {
        items = decoded['results'] as List<dynamic>;
      } else if (decoded is List) {
        items = decoded;
      } else {
        SmsLogger.sms('[AI] Unexpected response shape — skipping');
        return <AiParsedResult>[];
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map(AiParsedResult.fromJson)
          .toList();
    } catch (e) {
      SmsLogger.sms('[AI] Response parse error: $e');
      return <AiParsedResult>[];
    }
  }

  void dispose() => _client.close();
}
