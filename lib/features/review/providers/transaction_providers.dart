import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';

// ── Mock seed data ────────────────────────────────────────────────────────────

final List<TransactionModel> _mockTransactions = <TransactionModel>[
  TransactionModel(
    id: 1,
    merchant: 'Netflix',
    amount: 199.00,
    date: DateTime.now().subtract(const Duration(days: 1)),
    confirmationStatus: TxStatus.confirmed,
  ),
  TransactionModel(
    id: 2,
    merchant: 'Swiggy',
    amount: 349.50,
    date: DateTime.now().subtract(const Duration(days: 2)),
    confirmationStatus: TxStatus.confirmed,
  ),
  TransactionModel(
    id: 3,
    merchant: 'Unknown Merchant',
    amount: 1200.00,
    date: DateTime.now(),
    confirmationStatus: TxStatus.pending,
  ),
  TransactionModel(
    id: 4,
    merchant: 'UPI Transfer',
    amount: 500.00,
    date: DateTime.now(),
    confirmationStatus: TxStatus.pending,
  ),
];

// ── State notifier (controller) ───────────────────────────────────────────────

/// Manages the full in-memory transaction list and exposes confirm / ignore.
class TransactionController
    extends StateNotifier<List<TransactionModel>> {
  TransactionController() : super(List<TransactionModel>.from(_mockTransactions));

  /// Confirms a pending transaction and records the merchant as trusted.
  void confirm(int id) {
    state = <TransactionModel>[
      for (final tx in state)
        if (tx.id == id)
          tx.copyWith(confirmationStatus: TxStatus.confirmed)
        else
          tx,
    ];
  }

  /// Ignores a pending transaction — removes it from all views.
  void ignore(int id) {
    state = <TransactionModel>[
      for (final tx in state)
        if (tx.id == id)
          tx.copyWith(confirmationStatus: TxStatus.ignored)
        else
          tx,
    ];
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// All transactions (confirmed + pending, no ignored).
final transactionControllerProvider =
    StateNotifierProvider<TransactionController, List<TransactionModel>>(
  (ref) => TransactionController(),
);

/// Only confirmed transactions — main list.
final confirmedTransactionsProvider =
    Provider<List<TransactionModel>>((ref) {
  return ref
      .watch(transactionControllerProvider)
      .where((tx) => tx.isConfirmed)
      .toList();
});

/// Only pending transactions — "Needs Review" section.
final pendingTransactionsProvider =
    Provider<List<TransactionModel>>((ref) {
  return ref
      .watch(transactionControllerProvider)
      .where((tx) => tx.isPending)
      .toList();
});
