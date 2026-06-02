/// Represents a detected recurring/subscription payment pattern.
///
/// Persisted in the `subscriptions` SQLite table.
class DetectedSubscription {
  const DetectedSubscription({
    this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.lastPaidDate,
    required this.nextDueDate,
    required this.confidenceScore,
    this.isActive = true,
    required this.createdAt,
  });

  final int? id;

  /// Normalised (trimmed, uppercase) merchant name.
  final String merchant;

  final double amount;
  final String category;

  /// 'monthly' | 'weekly' | 'unknown'
  final String frequency;

  final DateTime lastPaidDate;
  final DateTime nextDueDate;

  /// 'low' | 'medium' | 'high'
  final String confidenceScore;

  final bool isActive;
  final DateTime createdAt;

  // ── Convenience ───────────────────────────────────────────────────────────

  bool get isMonthly => frequency == 'monthly';
  bool get isWeekly => frequency == 'weekly';
  bool get isHighConfidence => confidenceScore == 'high';

  // ── SQLite serialisation ──────────────────────────────────────────────────

  Map<String, Object?> toDbMap() => <String, Object?>{
        'merchant': merchant,
        'amount': amount,
        'category': category,
        'frequency': frequency,
        'last_paid_date': lastPaidDate.toIso8601String(),
        'next_due_date': nextDueDate.toIso8601String(),
        'confidence_score': confidenceScore,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, Object?> toMap() => <String, Object?>{'id': id, ...toDbMap()};

  factory DetectedSubscription.fromMap(Map<String, Object?> map) {
    return DetectedSubscription(
      id: map['id'] as int?,
      merchant: map['merchant'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      frequency: map['frequency'] as String,
      lastPaidDate: DateTime.parse(map['last_paid_date'] as String),
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      confidenceScore: map['confidence_score'] as String,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  DetectedSubscription copyWith({
    int? id,
    String? merchant,
    double? amount,
    String? category,
    String? frequency,
    DateTime? lastPaidDate,
    DateTime? nextDueDate,
    String? confidenceScore,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return DetectedSubscription(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'DetectedSubscription(id=$id, merchant=$merchant, '
      'amount=$amount, freq=$frequency, confidence=$confidenceScore, '
      'nextDue=$nextDueDate)';
}
