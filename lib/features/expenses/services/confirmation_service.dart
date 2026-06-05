import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';

/// Manages the smart confirmation layer.
///
/// Responsibilities:
/// - Check whether a newly-saved SMS expense should be auto-confirmed
///   (merchant is trusted from a prior user action).
/// - Confirm / ignore an expense on explicit user action.
/// - Persist merchant trust so future transactions are auto-confirmed.
class ConfirmationService {
  ConfirmationService({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  // ── Auto-confirm after SMS insert ─────────────────────────────────────────

  /// Called by [SmsTransactionProcessor] right after an expense is saved.
  ///
  /// If the merchant is already trusted, immediately upgrades the
  /// confirmation_status from 'pending' → 'confirmed' in the DB.
  Future<void> autoConfirmIfTrusted(int expenseId, String merchant) async {
    try {
      final pref = await _db.getMerchantPreference(merchant);
      if (pref != null && pref.isTrusted) {
        await _db.updateConfirmationStatus(
          expenseId,
          ConfirmationStatus.confirmed,
        );
        debugPrint(
          '[CONFIRM] Auto-confirmed expenseId=$expenseId merchant=$merchant',
        );
      }
    } catch (e) {
      debugPrint('[CONFIRM] autoConfirmIfTrusted error: $e');
    }
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Confirms an expense and marks the merchant as trusted for the future.
  Future<void> confirmExpense(Expense expense) async {
    if (expense.id == null) return;
    await _db.updateConfirmationStatus(
      expense.id!,
      ConfirmationStatus.confirmed,
    );
    // Learning: mark this merchant trusted so next occurrence is auto-confirmed.
    if (expense.merchant != null && expense.merchant!.isNotEmpty) {
      await _db.setMerchantTrusted(expense.merchant!, trusted: true);
      debugPrint(
        '[CONFIRM] Confirmed + trusted merchant=${expense.merchant}',
      );
    }
  }

  /// Ignores an expense — it disappears from all lists.
  Future<void> ignoreExpense(Expense expense) async {
    if (expense.id == null) return;
    await _db.updateConfirmationStatus(
      expense.id!,
      ConfirmationStatus.ignored,
    );
    debugPrint('[CONFIRM] Ignored expenseId=${expense.id}');
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<Expense>> getPendingExpenses() => _db.getPendingExpenses();

  Future<List<Expense>> getConfirmedExpenses() => _db.getConfirmedExpenses();
}
