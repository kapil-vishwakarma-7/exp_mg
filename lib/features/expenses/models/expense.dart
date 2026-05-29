class Expense {
  const Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });

  final int? id;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  Expense copyWith({
    int? id,
    double? amount,
    String? category,
    String? note,
    DateTime? date,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
