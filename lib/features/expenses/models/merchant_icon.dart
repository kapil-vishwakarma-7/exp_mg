/// Represents a merchant entry with optional locally-cached icon.
/// Persisted in the `merchants` SQLite table.
class MerchantIcon {
  const MerchantIcon({
    this.id,
    required this.name,
    this.domain,
    this.iconUrl,
    this.localIconPath,
    required this.category,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Normalised merchant name — lowercase, trimmed.
  /// Used as a unique key in the DB.
  final String name;

  /// Domain extracted from the merchant (e.g. "netflix.com").
  /// Used to build logo.dev URLs when no icon_url is provided.
  final String? domain;

  /// Remote icon URL (from AI API or backend). Source of truth for downloads.
  final String? iconUrl;

  /// Absolute file path to the locally cached icon PNG.
  /// Null until the icon is downloaded for the first time.
  final String? localIconPath;

  /// Fallback category for icon selection when no local icon exists.
  final String category;

  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasLocalIcon =>
      localIconPath != null && localIconPath!.isNotEmpty;

  bool get hasRemoteSource =>
      (iconUrl != null && iconUrl!.isNotEmpty) ||
      (domain != null && domain!.isNotEmpty);

  /// The effective download URL — tries multiple favicon sources.
  ///
  /// Priority:
  ///   1. Explicit iconUrl from the AI API (if provided)
  ///   2. logo.dev (high-quality brand logos, API key authenticated)
  ///   3. Google Favicon Service (free fallback)
  String? get resolvedIconUrl {
    if (iconUrl != null && iconUrl!.isNotEmpty) return iconUrl;
    if (domain != null && domain!.isNotEmpty) {
      return 'https://img.logo.dev/${domain!}?token=pk_ERFcDfM-R_u8Xp55ghzdNA&size=128&format=png';
    }
    return null;
  }

  /// Fallback URL used if the primary [resolvedIconUrl] returns a placeholder
  /// or fails.
  String? get fallbackIconUrl {
    if (domain != null && domain!.isNotEmpty) {
      return 'https://www.google.com/s2/favicons?sz=128&domain=${domain!}';
    }
    return null;
  }

  MerchantIcon copyWith({
    int? id,
    String? name,
    String? domain,
    String? iconUrl,
    String? localIconPath,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantIcon(
      id: id ?? this.id,
      name: name ?? this.name,
      domain: domain ?? this.domain,
      iconUrl: iconUrl ?? this.iconUrl,
      localIconPath: localIconPath ?? this.localIconPath,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDbMap() => <String, Object?>{
        'name': name,
        'domain': domain,
        'icon_url': iconUrl,
        'local_icon_path': localIconPath,
        'category': category,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory MerchantIcon.fromMap(Map<String, Object?> map) {
    return MerchantIcon(
      id: map['id'] as int?,
      name: map['name'] as String,
      domain: map['domain'] as String?,
      iconUrl: map['icon_url'] as String?,
      localIconPath: map['local_icon_path'] as String?,
      category: (map['category'] as String?) ?? 'Others',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'MerchantIcon(name=$name, domain=$domain, '
      'hasLocal=$hasLocalIcon)';
}
