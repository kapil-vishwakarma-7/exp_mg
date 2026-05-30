class Expense {
  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    DateTime? createdAt,
    this.transactionType,
    this.merchant,
    this.rawSms,
    this.smsHash,
  }) : createdAt = createdAt ?? date;

  final int? id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String note;
  final DateTime createdAt;
  final String? transactionType;
  final String? merchant;
  final String? rawSms;
  final String? smsHash;

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
    String? transactionType,
    String? merchant,
    String? rawSms,
    String? smsHash,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      transactionType: transactionType ?? this.transactionType,
      merchant: merchant ?? this.merchant,
      rawSms: rawSms ?? this.rawSms,
      smsHash: smsHash ?? this.smsHash,
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
      'transaction_type': transactionType,
      'merchant': merchant,
      'raw_sms': rawSms,
      'sms_hash': smsHash,
    };
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    final date = DateTime.parse(map['date'] as String);
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
      transactionType: map['transaction_type'] as String?,
      merchant: map['merchant'] as String?,
      rawSms: map['raw_sms'] as String?,
      smsHash: map['sms_hash'] as String?,
    );
  }
}
