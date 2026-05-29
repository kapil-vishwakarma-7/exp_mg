import '../utils/recurring_date_utils.dart';

class RecurringExpense {
  const RecurringExpense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.interval,
    required this.startDate,
    required this.nextDueDate,
    this.endDate,
    this.autoAdd = true,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final double amount;
  final String category;
  final String frequency;
  final int interval;
  final DateTime startDate;
  final DateTime nextDueDate;
  final DateTime? endDate;
  final bool autoAdd;
  final DateTime createdAt;

  RecurringExpense copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    String? frequency,
    int? interval,
    DateTime? startDate,
    DateTime? nextDueDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? autoAdd,
    DateTime? createdAt,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      autoAdd: autoAdd ?? this.autoAdd,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Map for SQLite insert/update (no id).
  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'title': title,
      'amount': amount,
      'category': category,
      'frequency': frequency.toLowerCase(),
      'repeat_interval': interval,
      'start_date': formatDbDate(startDate),
      'next_due_date': formatDbDate(nextDueDate),
      'end_date': endDate == null ? null : formatDbDate(endDate!),
      'auto_add': autoAdd ? 1 : 0,
      'created_at': formatDbDate(createdAt),
    };
  }

  Map<String, Object?> toMap() => <String, Object?>{'id': id, ...toDbMap()};

  factory RecurringExpense.fromMap(Map<String, Object?> map) {
    final intervalRaw = map['repeat_interval'] ?? map['interval'];
    final autoAddRaw = map['auto_add'];

    return RecurringExpense(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      frequency: (map['frequency'] as String).toLowerCase(),
      interval: intervalRaw == null ? 1 : (intervalRaw as num).toInt(),
      startDate: parseDbDate(map['start_date'] as String),
      nextDueDate: parseDbDate(map['next_due_date'] as String),
      endDate: map['end_date'] == null
          ? null
          : parseDbDate(map['end_date'] as String),
      autoAdd: autoAddRaw is bool
          ? autoAddRaw
          : (autoAddRaw as num).toInt() == 1,
      createdAt: parseDbDate(map['created_at'] as String),
    );
  }
}
