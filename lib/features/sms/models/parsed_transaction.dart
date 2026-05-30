class ParsedTransaction {
  const ParsedTransaction({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    required this.transactionTime,
    required this.rawSms,
    this.account,
    this.balance,
  });

  final double amount;
  final String type;
  final String merchant;
  final String category;
  final DateTime transactionTime;
  final String rawSms;
  final String? account;
  final double? balance;

  /// Alias for legacy code paths.
  DateTime get date => transactionTime;

  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';

  String get dedupeKey {
    final t = transactionTime;
    final bucket =
        '${t.year}-${t.month}-${t.day}-${t.hour}-${t.minute}';
    final accountPart = account ?? '';
    return '${amount.toStringAsFixed(2)}|$bucket|'
        '${merchant.toLowerCase().trim()}|$accountPart|'
        '${rawSms.hashCode}';
  }

  Map<String, Object?> toLogMap() => <String, Object?>{
        'amount': amount,
        'type': type,
        'merchant': merchant,
        'account': account,
        'balance': balance,
        'category': category,
        'transactionTime': transactionTime.toIso8601String(),
      };

  @override
  String toString() => 'ParsedTransaction(${toLogMap()})';
}
