/// Stores the user's trust preference for a merchant name.
/// Persisted in the `merchant_preferences` table.
class MerchantPreference {
  const MerchantPreference({
    this.id,
    required this.merchant,
    required this.isTrusted,
    required this.lastConfirmedAt,
  });

  final int? id;

  /// Normalised merchant name (uppercase, trimmed).
  final String merchant;

  final bool isTrusted;
  final DateTime lastConfirmedAt;

  Map<String, Object?> toDbMap() => <String, Object?>{
        'merchant': merchant,
        'is_trusted': isTrusted ? 1 : 0,
        'last_confirmed_at': lastConfirmedAt.toIso8601String(),
      };

  factory MerchantPreference.fromMap(Map<String, Object?> map) {
    return MerchantPreference(
      id: map['id'] as int?,
      merchant: map['merchant'] as String,
      isTrusted: (map['is_trusted'] as int) == 1,
      lastConfirmedAt:
          DateTime.parse(map['last_confirmed_at'] as String),
    );
  }

  MerchantPreference copyWith({
    bool? isTrusted,
    DateTime? lastConfirmedAt,
  }) {
    return MerchantPreference(
      id: id,
      merchant: merchant,
      isTrusted: isTrusted ?? this.isTrusted,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
    );
  }
}
