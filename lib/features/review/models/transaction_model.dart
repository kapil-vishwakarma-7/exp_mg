import 'package:intl/intl.dart';

/// Status values for the smart confirmation layer.
abstract final class TxStatus {
  static const String confirmed = 'confirmed';
  static const String pending = 'pending';
  static const String ignored = 'ignored';
}

/// Lightweight view-model used exclusively by the Riverpod review feature.
///
/// Intentionally decoupled from the existing [Expense] model so this module
/// can work standalone (and in tests) without touching the SQLite layer.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    this.confirmationStatus = TxStatus.pending,
  });

  final int id;
  final String merchant;
  final double amount;
  final DateTime date;

  /// One of [TxStatus] values.
  final String confirmationStatus;

  bool get isConfirmed => confirmationStatus == TxStatus.confirmed;
  bool get isPending => confirmationStatus == TxStatus.pending;
  bool get isIgnored => confirmationStatus == TxStatus.ignored;

  /// Formatted amount string: ₹1,234.00
  String get formattedAmount =>
      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(amount);

  /// Short date label: "12 Jun"
  String get shortDate => DateFormat('d MMM').format(date);

  TransactionModel copyWith({String? confirmationStatus}) {
    return TransactionModel(
      id: id,
      merchant: merchant,
      amount: amount,
      date: date,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
    );
  }

  @override
  String toString() =>
      'TransactionModel(id=$id, merchant=$merchant, '
      'amount=$amount, status=$confirmationStatus)';
}
