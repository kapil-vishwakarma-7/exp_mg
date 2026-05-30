class ParsedTransaction {
  const ParsedTransaction({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    required this.date,
    required this.rawSms,
    this.account,
    this.balance,
  });

  final double amount;
  final String type;
  final String merchant;
  final String category;
  final DateTime date;
  final String rawSms;
  final String? account;
  final double? balance;

  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';

  String get dedupeKey {
    final d = DateTime(date.year, date.month, date.day);
    final accountPart = account ?? '';
    return '${amount.toStringAsFixed(2)}|${d.toIso8601String()}|'
        '${merchant.toLowerCase().trim()}|$accountPart';
  }

  Map<String, Object?> toLogMap() => <String, Object?>{
        'amount': amount,
        'type': type,
        'merchant': merchant,
        'account': account,
        'balance': balance,
        'category': category,
        'date': date.toIso8601String(),
      };

  @override
  String toString() => 'ParsedTransaction(${toLogMap()})';
}
