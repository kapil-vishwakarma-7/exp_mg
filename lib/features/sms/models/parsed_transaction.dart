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
    this.isSubscription = false,
    this.subscriptionId,
  });

  final double amount;
  final String type;
  final String merchant;
  final String category;
  final DateTime transactionTime;
  final String rawSms;
  final String? account;
  final double? balance;

  /// True when the parser or subscription detector has identified this
  /// transaction as part of a recurring/subscription payment.
  final bool isSubscription;

  /// Foreign key into the `subscriptions` table once a subscription record
  /// has been created or matched for this transaction.
  final int? subscriptionId;

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

  ParsedTransaction copyWith({
    double? amount,
    String? type,
    String? merchant,
    String? category,
    DateTime? transactionTime,
    String? rawSms,
    String? account,
    double? balance,
    bool? isSubscription,
    int? subscriptionId,
  }) {
    return ParsedTransaction(
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      transactionTime: transactionTime ?? this.transactionTime,
      rawSms: rawSms ?? this.rawSms,
      account: account ?? this.account,
      balance: balance ?? this.balance,
      isSubscription: isSubscription ?? this.isSubscription,
      subscriptionId: subscriptionId ?? this.subscriptionId,
    );
  }

  Map<String, Object?> toLogMap() => <String, Object?>{
        'amount': amount,
        'type': type,
        'merchant': merchant,
        'account': account,
        'balance': balance,
        'category': category,
        'transactionTime': transactionTime.toIso8601String(),
        'isSubscription': isSubscription,
        'subscriptionId': subscriptionId,
      };

  @override
  String toString() => 'ParsedTransaction(${toLogMap()})';
}
