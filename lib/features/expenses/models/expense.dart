class Expense {
  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    DateTime? createdAt,
    DateTime? transactionTime,
    this.transactionType,
    this.merchant,
    this.rawSms,
    this.smsHash,
    this.isSubscription = false,
    this.subscriptionId,
    this.subscriptionFrequency,
  })  : createdAt = createdAt ?? date,
        transactionTime = transactionTime ?? date;

  final int? id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String note;
  final DateTime createdAt;
  final DateTime transactionTime;
  final String? transactionType;
  final String? merchant;
  final String? rawSms;
  final String? smsHash;

  /// True when this expense has been identified as a recurring/subscription payment.
  final bool isSubscription;

  /// FK into the subscriptions table (null for non-subscription expenses).
  final int? subscriptionId;

  /// Frequency string from the linked subscription ('monthly', 'weekly', …).
  final String? subscriptionFrequency;

  bool get isDebit => transactionType == null || transactionType == 'debit';
  bool get isCredit => transactionType == 'credit';

  Expense copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? transactionTime,
    String? transactionType,
    String? merchant,
    String? rawSms,
    String? smsHash,
    bool? isSubscription,
    int? subscriptionId,
    String? subscriptionFrequency,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      transactionTime: transactionTime ?? this.transactionTime,
      transactionType: transactionType ?? this.transactionType,
      merchant: merchant ?? this.merchant,
      rawSms: rawSms ?? this.rawSms,
      smsHash: smsHash ?? this.smsHash,
      isSubscription: isSubscription ?? this.isSubscription,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      subscriptionFrequency:
          subscriptionFrequency ?? this.subscriptionFrequency,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'transaction_time': transactionTime.toIso8601String(),
      'transaction_type': transactionType,
      'merchant': merchant,
      'raw_sms': rawSms,
      'sms_hash': smsHash,
      'is_subscription': isSubscription ? 1 : 0,
      'subscription_id': subscriptionId,
    };
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    final date = DateTime.parse(map['date'] as String);
    final transactionTime = map['transaction_time'] != null
        ? DateTime.parse(map['transaction_time'] as String)
        : date;
    return Expense(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? (map['merchant'] as String? ?? ''),
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: date,
      note: (map['note'] as String?) ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : date,
      transactionTime: transactionTime,
      transactionType: map['transaction_type'] as String?,
      merchant: map['merchant'] as String?,
      rawSms: map['raw_sms'] as String?,
      smsHash: map['sms_hash'] as String?,
      isSubscription: (map['is_subscription'] as int? ?? 0) == 1,
      subscriptionId: map['subscription_id'] as int?,
      // subscriptionFrequency is joined separately when needed.
    );
  }
}
