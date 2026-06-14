import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import '../models/sms_rule_file.dart';
import '../utils/sms_category_detector.dart';
import '../utils/sms_filter.dart';
import '../utils/sms_logger.dart';
import '../../expenses/models/expense.dart' show ConfidenceScore, ConfirmationStatus;
import 'ai_sms_api_client.dart';
import 'sms_parser.dart';
import 'sms_rule_repository.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const int _kBatchSize = 25;

// ── Pipeline result ───────────────────────────────────────────────────────────

class SmsBatchPipelineResult {
  const SmsBatchPipelineResult({
    required this.transactions,
    required this.processedCount,
    required this.skippedCount,
    required this.failedBatches,
  });

  /// Successfully parsed transactions ready to save, already deduplicated.
  final List<ParsedTransaction> transactions;

  /// SMS that passed the filter and were sent to the AI API.
  final int processedCount;

  /// SMS skipped (non-transactional or already in DB).
  final int skippedCount;

  /// Batches that failed all retries and fell back to the rule parser.
  final int failedBatches;

  @override
  String toString() =>
      'SmsBatchPipelineResult(transactions=${transactions.length}, '
      'processed=$processedCount, skipped=$skippedCount, '
      'failedBatches=$failedBatches)';
}

// ── Processor ─────────────────────────────────────────────────────────────────

/// Orchestrates the AI-enhanced SMS parsing pipeline for bulk inbox scans.
///
/// Pipeline (matches the spec exactly):
///
///   1. [filterTransactionalSms]     — rule-based pre-filter (cost reduction)
///   2. Skip already-processed SMS   — isProcessed via [alreadyProcessedHashes]
///   3. [chunkArray]                 — split into ≤ 25-message batches
///   4. [callParserAPI] per batch    — parallel calls, retry × 2, never throws
///   5. Merge + deduplicate results
///   6. Fall back to [SmsParser]     — for any batch that failed all retries
///
/// Live incoming SMS bypass this entirely — they continue through
/// [AndroidSmsService.handleMessage] → [SmsParser] for low latency.
///
/// Swap the AI provider by injecting a different [AiSmsApiClient] subclass.
class SmsBatchProcessor {
  SmsBatchProcessor({
    AiSmsApiClient? apiClient,
    SmsParser? fallbackParser,
    SmsRuleRepository? repository,
  })  : _apiClient = apiClient ?? AiSmsApiClient(),
        _fallbackParser = fallbackParser ?? SmsParser(),
        _repo = repository ?? SmsRuleRepository.instance;

  final AiSmsApiClient _apiClient;
  final SmsParser _fallbackParser;
  final SmsRuleRepository _repo;

  SmsRuleFile get _rules => _repo.rules;

  // ── Public entry point ────────────────────────────────────────────────────

  /// Run the full pipeline on [messages].
  ///
  /// Pass [alreadyProcessedHashes] (a set of sms body-hash|sender|date strings)
  /// to skip SMS already present in the DB.
  Future<SmsBatchPipelineResult> processSMSPipeline(
    List<SmsMessage> messages, {
    Set<String> alreadyProcessedHashes = const <String>{},
  }) async {
    // ── Edge case: empty input ────────────────────────────────────────────
    if (messages.isEmpty) {
      SmsLogger.sms('[BATCH] Empty list — nothing to process');
      return const SmsBatchPipelineResult(
        transactions: <ParsedTransaction>[],
        processedCount: 0,
        skippedCount: 0,
        failedBatches: 0,
      );
    }

    // ── Step 1: filter ────────────────────────────────────────────────────
    final filtered = filterTransactionalSms(messages, rules: _rules);
    final nonTransactional = messages.length - filtered.length;

    SmsLogger.sms(
      '[BATCH] Filter: ${messages.length} total → '
      '${filtered.length} transactional, $nonTransactional skipped',
    );

    if (filtered.isEmpty) {
      return SmsBatchPipelineResult(
        transactions: const <ParsedTransaction>[],
        processedCount: 0,
        skippedCount: nonTransactional,
        failedBatches: 0,
      );
    }

    // ── Step 2: skip already-processed ───────────────────────────────────
    final newMessages = <SmsMessage>[];
    for (final msg in filtered) {
      if (alreadyProcessedHashes.contains(_preprocessKey(msg))) {
        SmsLogger.sms('[BATCH] isProcessed=true, skipping: ${msg.sender}');
        continue;
      }
      newMessages.add(msg);
    }

    final alreadyProcessed = filtered.length - newMessages.length;
    final totalSkipped = nonTransactional + alreadyProcessed;

    SmsLogger.sms(
      '[BATCH] ${newMessages.length} new messages '
      '($alreadyProcessed already processed)',
    );

    if (newMessages.isEmpty) {
      return SmsBatchPipelineResult(
        transactions: const <ParsedTransaction>[],
        processedCount: 0,
        skippedCount: totalSkipped,
        failedBatches: 0,
      );
    }

    // ── Step 3: chunk ─────────────────────────────────────────────────────
    final batches = chunkArray(newMessages, _kBatchSize);
    SmsLogger.sms(
      '[BATCH] ${batches.length} batch(es) of ≤$_kBatchSize messages',
    );

    // ── Step 4: parallel API calls (Promise.allSettled equivalent) ────────
    // Future.wait with eagerError: false collects all results even when
    // individual batches fail — equivalent to JS Promise.allSettled.
    final batchFutures = batches.map(_processBatch).toList();
    final outcomes = await Future.wait<_BatchOutcome>(
      batchFutures,
      eagerError: false,
    );

    // ── Step 5: merge + deduplicate ───────────────────────────────────────
    final allTransactions = <ParsedTransaction>[];
    var failedBatches = 0;

    for (final outcome in outcomes) {
      if (outcome.apiSucceeded) {
        allTransactions.addAll(outcome.transactions);
      } else {
        // Step 6: fallback — rule parser for this failed batch
        failedBatches++;
        SmsLogger.sms(
          '[BATCH] Batch failed (${outcome.error}) — '
          'rule-parser fallback for ${outcome.originalMessages.length} msg(s)',
        );
        for (final msg in outcome.originalMessages) {
          final parsed = _fallbackParser.parse(msg);
          if (parsed != null) allTransactions.add(parsed);
        }
      }
    }

    // Deduplicate by dedupeKey.
    final seen = <String>{};
    final unique = allTransactions.where((tx) => seen.add(tx.dedupeKey)).toList();

    SmsLogger.sms(
      '[BATCH] Done: ${unique.length} unique transactions '
      '(${allTransactions.length - unique.length} dupes removed), '
      '$failedBatches failed batch(es)',
    );

    return SmsBatchPipelineResult(
      transactions: unique,
      processedCount: newMessages.length,
      skippedCount: totalSkipped,
      failedBatches: failedBatches,
    );
  }

  // ── Step 1 helper — filterTransactionalSms() ─────────────────────────────

  /// Returns only SMS that pass the rule-based transactional filter.
  /// Static so callers can use it independently (e.g. for testing).
  static List<SmsMessage> filterTransactionalSms(
    List<SmsMessage> messages, {
    SmsRuleFile? rules,
  }) {
    return messages
        .where(
          (m) => isRelevantTransactionSms(
            m.body,
            rules: rules,
            logRejections: false,
          ),
        )
        .toList();
  }

  // ── Step 3 helper — chunkArray() ─────────────────────────────────────────

  /// Splits [list] into sub-lists of at most [size] items.
  static List<List<T>> chunkArray<T>(List<T> list, int size) {
    assert(size > 0);
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, (i + size).clamp(0, list.length)));
    }
    return chunks;
  }

  // ── Step 4 helper — callParserAPI() ──────────────────────────────────────

  /// Calls the AI API for one batch and maps results back to transactions.
  /// Never throws — failures are captured in [_BatchOutcome.error].
  Future<_BatchOutcome> _processBatch(List<SmsMessage> messages) async {
    // Build text → SmsMessage map for O(1) correlation after API response.
    final textToMsg = <String, SmsMessage>{
      for (final m in messages) m.body: m,
    };

    final inputs = messages
        .map((m) => AiSmsInput(sender: m.sender, text: m.body))
        .toList();

    final callResult = await _apiClient.callBatch(inputs);

    if (!callResult.succeeded) {
      return _BatchOutcome(
        originalMessages: messages,
        transactions: const <ParsedTransaction>[],
        apiSucceeded: false,
        error: callResult.error,
      );
    }

    // Map AI results → ParsedTransaction objects.
    final transactions = <ParsedTransaction>[];

    for (final result in callResult.results) {
      if (!result.looksLikeTransaction) continue;

      final original = textToMsg[result.originalText];
      final txTime = result.transactionDate ?? original?.date ?? DateTime.now();

      final merchant = _normaliseMerchant(result.merchant);
      final category = (result.category?.isNotEmpty == true)
          ? result.category!
          : detectSmsCategory(
              merchant,
              messageBody: result.originalText,
              rules: _rules,
            );

      // AI-parsed transactions get high confidence and are auto-confirmed —
      // a dedicated model is more reliable than a generic rule match.
      transactions.add(
        ParsedTransaction(
          amount: result.amount!,
          type: result.type!,
          merchant: merchant,
          category: category,
          transactionTime: txTime,
          rawSms: result.originalText,
          account: result.account,
          balance: result.balance,
          confidenceScore: ConfidenceScore.high,
          confirmationStatus: ConfirmationStatus.confirmed,
        ),
      );
    }

    SmsLogger.sms(
      '[BATCH] ${messages.length} msgs → '
      '${transactions.length} transactions from AI',
    );

    return _BatchOutcome(
      originalMessages: messages,
      transactions: transactions,
      apiSucceeded: true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Lightweight pre-processing key for the isProcessed check.
  String _preprocessKey(SmsMessage msg) {
    final t = msg.date;
    final bucket = '${t.year}-${t.month}-${t.day}';
    return '${msg.body.hashCode}|${msg.sender}|$bucket';
  }

  String _normaliseMerchant(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Unknown';
    var v = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.length > 40) v = v.substring(0, 40).trim();
    return v;
  }

  void dispose() => _apiClient.dispose();
}

// ── Internal outcome type ─────────────────────────────────────────────────────

class _BatchOutcome {
  const _BatchOutcome({
    required this.originalMessages,
    required this.transactions,
    required this.apiSucceeded,
    this.error,
  });

  final List<SmsMessage> originalMessages;
  final List<ParsedTransaction> transactions;
  final bool apiSucceeded;
  final String? error;
}
