import 'dart:async';
import 'dart:io' show Platform;

import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import '../utils/sms_filter.dart';
import '../utils/sms_logger.dart';
import '../utils/sms_permissions.dart';
import 'ai_sms_api_client.dart';
import 'platform/sms_platform_factory.dart' show createSmsPlatform;
import 'platform/sms_platform_stub.dart';
import 'sms_batch_processor.dart';
import 'sms_parser.dart';
import 'sms_service.dart';
import 'sms_transaction_processor.dart';

/// Android-only SMS service: inbox read + live listener.
///
/// ## Live SMS strategy (AI-enhanced, non-blocking)
///
/// When a live message arrives:
///   1. Rule parser runs **synchronously** — instant result, saves to DB.
///   2. AI API call fires in the background (fire-and-forget).
///   3. If the AI returns a better result (merchant / category / confidence),
///      the saved record is patched via [SmsTransactionProcessor.enrichIfBetter].
///
/// This keeps the listener latency at ~0ms while still improving accuracy
/// for most messages once the AI responds (~1-3s later).
class AndroidSmsService implements SmsService {
  AndroidSmsService({
    SmsPlatform? platform,
    SmsParser? parser,
    SmsTransactionProcessor? processor,
    SmsPermissions? permissions,
    AiSmsApiClient? aiClient,
    SmsBatchProcessor? batchProcessor,
  })  : _platform = platform ?? createSmsPlatform(),
        _parser = parser ?? SmsParser(),
        _processor = processor ?? SmsTransactionProcessor(),
        _permissions = permissions ?? const SmsPermissions(),
        _aiClient = aiClient ?? AiSmsApiClient(),
        _batchProcessor = batchProcessor ?? SmsBatchProcessor();

  final SmsPlatform _platform;
  final SmsParser _parser;
  final SmsTransactionProcessor _processor;
  final SmsPermissions _permissions;
  final AiSmsApiClient _aiClient;
  final SmsBatchProcessor _batchProcessor;

  final StreamController<SmsMessage> _incoming =
      StreamController<SmsMessage>.broadcast();

  SmsMessage? lastReceivedSms;
  SmsHandleOutcome? lastOutcome;

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Stream<SmsMessage> get incomingMessages => _incoming.stream;

  // ── Permissions ───────────────────────────────────────────────────────────

  @override
  Future<bool> requestPermissions() async {
    if (!isSupported) {
      SmsLogger.sms('requestPermissions skipped — not Android');
      return false;
    }
    SmsLogger.sms('Requesting SMS permissions…');
    final handlerOk = await _permissions.requestSmsPermissions();
    if (!handlerOk) {
      SmsLogger.sms('Permission denied via permission_handler');
      return false;
    }
    final telephonyOk = await _platform.requestPermissions();
    if (!telephonyOk) {
      SmsLogger.sms('Permission denied via telephony');
    }
    return telephonyOk;
  }

  // ── Inbox fetch ───────────────────────────────────────────────────────────

  @override
  Future<List<SmsMessage>> fetchMessages() async {
    if (!isSupported) return const <SmsMessage>[];
    return _platform.readInbox();
  }

  // ── Live listener ─────────────────────────────────────────────────────────

  @override
  Future<void> startListening() async {
    if (!isSupported) return;
    await _platform.startListening(_onIncoming);
  }

  @override
  Future<void> stopListening() async {
    await _platform.stopListening();
  }

  void _onIncoming(SmsMessage message) {
    if (_incoming.isClosed) return;
    _incoming.add(message);
    unawaited(handleMessage(message));
  }

  // ── Core message handler ──────────────────────────────────────────────────

  @override
  Future<ParsedTransaction?> handleMessage(SmsMessage message) async {
    lastReceivedSms = message;
    SmsLogger.sms(
      'Processing SMS -> From: ${message.sender} | Body: ${message.body}',
    );

    try {
      // ── Step 1: rule-based parse (instant, no network) ──────────────────
      final ruleParsed = _parser.parse(message);

      if (ruleParsed == null) {
        // Rule parser rejected it. Still attempt AI if it looks transactional
        // at the keyword level — the AI may catch edge cases the rules miss.
        if (!isRelevantTransactionSms(message.body, logRejections: false)) {
          lastOutcome = const SmsHandleOutcome(
            stage: 'parse_failed',
            detail: 'Filtered out — not transactional',
          );
          SmsLogger.sms('Skipped SMS — not transactional');
          return null;
        }

        // Potentially transactional but rule parser missed it —
        // send straight to AI (synchronously for live SMS since we have no
        // rule result to save first).
        SmsLogger.sms(
          '[LIVE][AI] Rule missed — attempting AI-only parse',
        );
        return _handleWithAiOnly(message);
      }

      // ── Step 2: save rule result immediately ────────────────────────────
      SmsLogger.sms('Rule parsed: ${ruleParsed.toLogMap()}');
      final saved = await _processor.saveIfNew(ruleParsed);

      if (!saved) {
        lastOutcome = const SmsHandleOutcome(
          stage: 'duplicate',
          detail: 'Hash already exists in DB',
        );
        SmsLogger.sms('Duplicate detected — not saved');
        return null;
      }

      lastOutcome = SmsHandleOutcome(stage: 'saved', transaction: ruleParsed);
      SmsLogger.sms('Transaction saved (rule parser)');

      // ── Step 3: AI enrichment in background ─────────────────────────────
      // Fire-and-forget — never blocks the listener or the caller.
      unawaited(_enrichWithAi(message, ruleParsed));

      return ruleParsed;
    } catch (error, stackTrace) {
      lastOutcome = SmsHandleOutcome(
        stage: 'error',
        detail: error.toString(),
      );
      SmsLogger.sms('Error handling SMS: $error');
      SmsLogger.sms('$stackTrace');
      return null;
    }
  }

  // ── AI-only path (rule parser returned null) ──────────────────────────────

  /// Used when the rule parser rejects a message that still looks transactional.
  /// Waits for the AI response synchronously so we have something to save.
  Future<ParsedTransaction?> _handleWithAiOnly(SmsMessage message) async {
    try {
      final result = await _callAiForOne(message);
      if (result == null) {
        lastOutcome = const SmsHandleOutcome(
          stage: 'parse_failed',
          detail: 'AI also did not detect a transaction',
        );
        SmsLogger.sms('[LIVE][AI] No transaction detected by AI');
        return null;
      }

      final saved = await _processor.saveIfNew(result);
      if (!saved) {
        lastOutcome = const SmsHandleOutcome(
          stage: 'duplicate',
          detail: 'Hash already exists in DB',
        );
        return null;
      }

      lastOutcome = SmsHandleOutcome(stage: 'saved', transaction: result);
      SmsLogger.sms('[LIVE][AI] Transaction saved via AI-only path');
      return result;
    } catch (e, st) {
      SmsLogger.sms('[LIVE][AI] AI-only path error: $e\n$st');
      return null;
    }
  }

  // ── Background AI enrichment ──────────────────────────────────────────────

  /// Calls the AI API after the rule result is already saved.
  ///
  /// If the AI produces a higher-confidence result with a better merchant
  /// name or category, the saved record is updated in place.
  Future<void> _enrichWithAi(
    SmsMessage message,
    ParsedTransaction ruleParsed,
  ) async {
    try {
      SmsLogger.sms('[LIVE][AI] Background enrichment started');
      final aiResult = await _callAiForOne(message);

      if (aiResult == null) {
        SmsLogger.sms('[LIVE][AI] AI found no transaction — keeping rule result');
        return;
      }

      // Determine if AI result is meaningfully better.
      final merchantImproved = aiResult.merchant != 'Unknown' &&
          (ruleParsed.merchant == 'Unknown' ||
              aiResult.merchant.length > ruleParsed.merchant.length);
      final categoryImproved = aiResult.category != ruleParsed.category &&
          aiResult.category != 'Others';

      if (!merchantImproved && !categoryImproved) {
        SmsLogger.sms('[LIVE][AI] AI result not better — no update needed');
        return;
      }

      // Patch the saved record with AI improvements while preserving the
      // rule-parsed amount, type, date, and dedupeKey.
      final enriched = ruleParsed.copyWith(
        merchant: merchantImproved ? aiResult.merchant : ruleParsed.merchant,
        category: categoryImproved ? aiResult.category : ruleParsed.category,
        confidenceScore: 'high', // AI-touched = high confidence
        confirmationStatus: 'confirmed',
      );

      await _processor.enrichTransaction(ruleParsed, enriched);
      SmsLogger.sms(
        '[LIVE][AI] Enriched — merchant=${enriched.merchant} '
        'category=${enriched.category}',
      );
    } catch (e) {
      // Never crash the pipeline on enrichment failure.
      SmsLogger.sms('[LIVE][AI] Enrichment error (ignored): $e');
    }
  }

  // ── Single-message AI call ────────────────────────────────────────────────

  /// Sends exactly one message to the AI API (as a single-item batch).
  Future<ParsedTransaction?> _callAiForOne(SmsMessage message) async {
    final batchResult = await _aiClient.callBatch(
      <AiSmsInput>[AiSmsInput(sender: message.sender, text: message.body)],
    );

    if (!batchResult.succeeded || batchResult.results.isEmpty) return null;

    final result = batchResult.results.first;
    if (!result.looksLikeTransaction) return null;

    // Delegate mapping to the batch processor's internal logic via
    // processSMSPipeline on a single-item list — reuses all normalisation.
    final pipeline = await _batchProcessor.processSMSPipeline(
      <SmsMessage>[message],
    );
    return pipeline.transactions.isNotEmpty
        ? pipeline.transactions.first
        : null;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopListening();
    await _incoming.close();
    _aiClient.dispose();
    _batchProcessor.dispose();
  }
}
