import 'package:flutter/foundation.dart';

import '../../expenses/database/database_helper.dart';
import '../../expenses/utils/recurring_date_utils.dart';
import '../models/detected_subscription.dart';
import '../models/parsed_transaction.dart';
import '../models/sms_rule_file.dart';
import '../utils/sms_logger.dart';
import 'sms_rule_repository.dart';

/// Detects and persists subscription/recurring payment patterns.
///
/// Called by [SmsTransactionProcessor] after a transaction is saved.
/// All errors are caught and logged — this never breaks the SMS pipeline.
class SubscriptionService {
  SubscriptionService({
    DatabaseHelper? db,
    SmsRuleRepository? repository,
  })  : _db = db ?? DatabaseHelper.instance,
        _repo = repository ?? SmsRuleRepository.instance;

  final DatabaseHelper _db;
  final SmsRuleRepository _repo;

  SubscriptionDetectionConfig get _config =>
      _repo.rules.subscriptionDetection;

  // ── Public entry point ────────────────────────────────────────────────────

  /// Analyse [transaction] for subscription patterns. If detected, create or
  /// update a subscription record and return it (with its DB id). Returns null
  /// when not a subscription or on any error.
  ///
  /// [savedExpenseId] is the expenses.id of the just-inserted row so we can
  /// link it back after detection.
  Future<DetectedSubscription?> detectAndLink(
    ParsedTransaction transaction, {
    required int savedExpenseId,
  }) async {
    try {
      // Only process debit transactions.
      if (!transaction.isDebit) return null;

      final lower = transaction.rawSms.toLowerCase();

      // Step 9 — ignore salary, self-transfer keywords.
      final ignoreList = _repo.rules.ignoreKeywords;
      if (ignoreList.any(lower.contains)) {
        SmsLogger.sms(
          '[SUB] Ignored — matches ignore keyword: ${transaction.merchant}',
        );
        return null;
      }

      final merchantKey = _normaliseMerchant(transaction.merchant);
      if (merchantKey.isEmpty || merchantKey == 'UNKNOWN') return null;

      // Step 1 — rule-flagged subscription (is_subscription from parser).
      // Step 4 — known subscription merchant list.
      final knownSub = _isKnownSubscriptionMerchant(merchantKey);

      // Step 2 — keyword hit in SMS body.
      final keywordHit = _hasSubscriptionKeyword(lower);

      // Fetch recent transactions for this merchant.
      final history = await _db.getExpensesByMerchant(
        merchantKey,
        limit: _config.minMatches + 5,
      );

      // Step 5 — pattern detection: amount + date regularity.
      final patternResult = _analysePattern(
        current: transaction,
        history: history,
      );

      final isSubscription = transaction.isSubscription ||
          knownSub ||
          (keywordHit && patternResult.matchCount >= 1) ||
          patternResult.matchCount >= _config.minMatches;

      if (!isSubscription) return null;

      final confidence = _computeConfidence(
        isKnownMerchant: knownSub,
        isRuleFlagged: transaction.isSubscription,
        keywordHit: keywordHit,
        matchCount: patternResult.matchCount,
      );

      SmsLogger.sms(
        '[SUB] Detected — merchant=$merchantKey '
        'confidence=$confidence freq=${patternResult.frequency}',
      );

      // Upsert subscription record.
      final sub = await _upsertSubscription(
        merchantKey: merchantKey,
        transaction: transaction,
        frequency: patternResult.frequency,
        confidence: confidence,
      );

      // Link expense → subscription.
      if (sub.id != null) {
        await _db.linkExpenseToSubscription(savedExpenseId, sub.id!);
      }

      return sub;
    } catch (e, st) {
      debugPrint('[SUB] detectAndLink error: $e\n$st');
      return null;
    }
  }

  /// Returns all active subscriptions with next_due_date in next [daysAhead].
  Future<List<DetectedSubscription>> getUpcomingSubscriptions({
    int daysAhead = 7,
  }) {
    return _db.getUpcomingSubscriptions(daysAhead: daysAhead);
  }

  /// Returns all active subscriptions.
  Future<List<DetectedSubscription>> getAllSubscriptions() {
    return _db.getAllSubscriptions();
  }

  // ── Step 3 — merchant normalisation ──────────────────────────────────────

  /// Uppercase, trimmed. "Netflix" → "NETFLIX".
  String _normaliseMerchant(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  // ── Step 4 — known merchant check ────────────────────────────────────────

  bool _isKnownSubscriptionMerchant(String merchantKey) {
    final lower = merchantKey.toLowerCase();
    return _repo.rules.subscriptionMerchants.any(lower.contains);
  }

  // ── Step 2 — keyword check ────────────────────────────────────────────────

  bool _hasSubscriptionKeyword(String lowerBody) {
    return _config.keywords.any(lowerBody.contains);
  }

  // ── Step 5 — pattern analysis ─────────────────────────────────────────────

  _PatternResult _analysePattern({
    required ParsedTransaction current,
    required List<Map<String, Object?>> history,
  }) {
    if (history.isEmpty) {
      return const _PatternResult(matchCount: 0, frequency: 'unknown');
    }

    var matchCount = 0;
    final dayGaps = <int>[];
    final currentDate = dateOnly(current.transactionTime);

    for (final row in history) {
      final rowAmount = (row['amount'] as num).toDouble();
      final rawDate =
          (row['transaction_time'] as String?) ?? (row['date'] as String);
      final rowDate = dateOnly(DateTime.parse(rawDate));

      final amountDiff = (rowAmount - current.amount).abs();
      if (amountDiff > _config.amountTolerance) continue;

      final gap = currentDate.difference(rowDate).inDays.abs();
      if (gap == 0) continue; // same transaction

      matchCount++;
      dayGaps.add(gap);
    }

    final frequency = _inferFrequency(dayGaps);

    return _PatternResult(matchCount: matchCount, frequency: frequency);
  }

  String _inferFrequency(List<int> dayGaps) {
    if (dayGaps.isEmpty) return 'unknown';
    // Use the smallest gap as the best signal.
    dayGaps.sort();
    final gap = dayGaps.first;
    if (gap >= 25 && gap <= 35) return 'monthly';
    if (gap >= 6 && gap <= 8) return 'weekly';
    if (gap >= 13 && gap <= 16) return 'biweekly';
    if (gap >= 85 && gap <= 95) return 'quarterly';
    if (gap >= 360 && gap <= 370) return 'yearly';
    return 'monthly'; // best-effort default
  }

  // ── Confidence scoring ────────────────────────────────────────────────────

  String _computeConfidence({
    required bool isKnownMerchant,
    required bool isRuleFlagged,
    required bool keywordHit,
    required int matchCount,
  }) {
    var score = 0;
    if (isKnownMerchant) score += 3;
    if (isRuleFlagged) score += 2;
    if (keywordHit) score += 1;
    if (matchCount >= _config.minMatches) score += 2;
    if (matchCount >= _config.minMatches + 1) score += 1;

    if (score >= 5) return 'high';
    if (score >= 2) return 'medium';
    return 'low';
  }

  // ── Upsert subscription record ────────────────────────────────────────────

  Future<DetectedSubscription> _upsertSubscription({
    required String merchantKey,
    required ParsedTransaction transaction,
    required String frequency,
    required String confidence,
  }) async {
    final existing = await _db.getSubscriptionByMerchant(merchantKey);
    final now = DateTime.now();
    final lastPaid = dateOnly(transaction.transactionTime);
    final nextDue = _computeNextDue(lastPaid, frequency);

    if (existing != null) {
      // Update existing record.
      final updated = existing.copyWith(
        amount: transaction.amount,
        lastPaidDate: lastPaid,
        nextDueDate: nextDue,
        confidenceScore: confidence,
        frequency: frequency,
        isActive: true,
      );
      await _db.updateSubscription(updated);
      SmsLogger.sms(
        '[SUB] Updated subscription id=${existing.id} merchant=$merchantKey',
      );
      return updated;
    }

    // Create new record.
    final newSub = DetectedSubscription(
      merchant: merchantKey,
      amount: transaction.amount,
      category: transaction.category,
      frequency: frequency,
      lastPaidDate: lastPaid,
      nextDueDate: nextDue,
      confidenceScore: confidence,
      isActive: true,
      createdAt: dateOnly(now),
    );
    final id = await _db.insertSubscription(newSub);
    SmsLogger.sms('[SUB] Created subscription id=$id merchant=$merchantKey');
    return newSub.copyWith(id: id);
  }

  DateTime _computeNextDue(DateTime lastPaid, String frequency) {
    switch (frequency) {
      case 'weekly':
        return lastPaid.add(const Duration(days: 7));
      case 'biweekly':
        return lastPaid.add(const Duration(days: 14));
      case 'quarterly':
        return DateTime(lastPaid.year, lastPaid.month + 3, lastPaid.day);
      case 'yearly':
        return DateTime(lastPaid.year + 1, lastPaid.month, lastPaid.day);
      case 'monthly':
      default:
        return DateTime(lastPaid.year, lastPaid.month + 1, lastPaid.day);
    }
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _PatternResult {
  const _PatternResult({
    required this.matchCount,
    required this.frequency,
  });

  final int matchCount;
  final String frequency;
}
