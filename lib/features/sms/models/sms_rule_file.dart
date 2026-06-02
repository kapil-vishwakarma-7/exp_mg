import 'dart:convert';

/// Typed representation of `sms_rules_v1.json`.
///
/// All fields have safe defaults so a partially-formed JSON never crashes
/// the parser — it just falls back to the built-in values.
class SmsRuleFile {
  SmsRuleFile({
    required this.version,
    required this.updatedAt,
    required this.includeKeywords,
    required this.excludeKeywords,
    required this.categoryKeywords,
    required this.debitPatterns,
    required this.creditPatterns,
    required this.merchantPatterns,
  });

  final int version;
  final String updatedAt;

  /// Keywords whose presence marks an SMS as a potential transaction.
  final List<String> includeKeywords;

  /// Keywords that disqualify an SMS (OTPs, offers, balance queries, etc.).
  final List<String> excludeKeywords;

  /// merchant-keyword → category mapping (lowercase keys).
  final Map<String, String> categoryKeywords;

  /// Regex strings (caseSensitive: false) for debit amount extraction.
  final List<String> debitPatterns;

  /// Regex strings (caseSensitive: false) for credit amount extraction.
  final List<String> creditPatterns;

  /// Regex strings (caseSensitive: false) for merchant name extraction.
  final List<String> merchantPatterns;

  // ── Parsing ──────────────────────────────────────────────────────────────

  factory SmsRuleFile.fromJson(Map<String, dynamic> json) {
    return SmsRuleFile(
      version: (json['version'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as String?) ?? '',
      includeKeywords: _stringList(json['includeKeywords']),
      excludeKeywords: _stringList(json['excludeKeywords']),
      categoryKeywords: _stringMap(json['categoryKeywords']),
      debitPatterns: _stringList(json['debitPatterns']),
      creditPatterns: _stringList(json['creditPatterns']),
      merchantPatterns: _stringList(json['merchantPatterns']),
    );
  }

  factory SmsRuleFile.fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return SmsRuleFile.fromJson(map);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'updatedAt': updatedAt,
        'includeKeywords': includeKeywords,
        'excludeKeywords': excludeKeywords,
        'categoryKeywords': categoryKeywords,
        'debitPatterns': debitPatterns,
        'creditPatterns': creditPatterns,
        'merchantPatterns': merchantPatterns,
      };

  String toJsonString() => jsonEncode(toJson());

  // ── Compiled regex accessors (lazy, cached per instance) ─────────────────

  List<RegExp>? _compiledDebit;
  List<RegExp>? _compiledCredit;
  List<RegExp>? _compiledMerchant;

  List<RegExp> get compiledDebitPatterns =>
      _compiledDebit ??= _compile(debitPatterns);

  List<RegExp> get compiledCreditPatterns =>
      _compiledCredit ??= _compile(creditPatterns);

  List<RegExp> get compiledMerchantPatterns =>
      _compiledMerchant ??= _compile(merchantPatterns);

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.cast<String>();
    return <String>[];
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    return <String, String>{};
  }

  static List<RegExp> _compile(List<String> patterns) {
    final result = <RegExp>[];
    for (final p in patterns) {
      try {
        result.add(RegExp(p, caseSensitive: false));
      } catch (_) {
        // Skip invalid regex — never crash the parser.
      }
    }
    return result;
  }

  @override
  String toString() =>
      'SmsRuleFile(version=$version, updatedAt=$updatedAt, '
      'include=${includeKeywords.length}, exclude=${excludeKeywords.length}, '
      'categories=${categoryKeywords.length})';
}
