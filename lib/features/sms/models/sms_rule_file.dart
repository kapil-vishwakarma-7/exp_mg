import 'dart:convert';

// ── Subscription detection config ─────────────────────────────────────────────

class SubscriptionDetectionConfig {
  const SubscriptionDetectionConfig({
    required this.keywords,
    required this.minMatches,
    required this.amountTolerance,
    required this.dayTolerance,
  });

  /// SMS body keywords that signal a recurring/subscription payment.
  final List<String> keywords;

  /// How many past transactions with matching amount must exist to confirm.
  final int minMatches;

  /// Maximum ₹ difference allowed between occurrences to be considered same.
  final double amountTolerance;

  /// ±days window when comparing payment dates across months.
  final int dayTolerance;

  factory SubscriptionDetectionConfig.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetectionConfig(
      keywords: _strList(json['keywords']),
      minMatches: (json['minMatches'] as num?)?.toInt() ?? 2,
      amountTolerance: (json['amountTolerance'] as num?)?.toDouble() ?? 10.0,
      dayTolerance: (json['dayTolerance'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'keywords': keywords,
        'minMatches': minMatches,
        'amountTolerance': amountTolerance,
        'dayTolerance': dayTolerance,
      };

  /// Default config used when the rule file has no subscriptionDetection block.
  static const SubscriptionDetectionConfig defaults =
      SubscriptionDetectionConfig(
    keywords: <String>[
      'autopay',
      'subscription',
      'recurring',
      'mandate',
      'emi',
      'bill payment',
      'auto debit',
      'standing instruction',
      'nach debit',
    ],
    minMatches: 2,
    amountTolerance: 10.0,
    dayTolerance: 3,
  );

  static List<String> _strList(dynamic raw) =>
      raw is List ? raw.cast<String>() : <String>[];
}

// ── Main rule file model ──────────────────────────────────────────────────────

/// Typed representation of `sms_rules_v1.json`.
///
/// All fields have safe defaults so a partially-formed remote JSON never
/// crashes the parser — it falls back to the built-in values.
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
    required this.subscriptionDetection,
    required this.subscriptionMerchants,
    required this.ignoreKeywords,
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

  /// Configuration for the pattern-based subscription detector.
  final SubscriptionDetectionConfig subscriptionDetection;

  /// Lowercase merchant name fragments that are always treated as subscriptions.
  final List<String> subscriptionMerchants;

  /// Keywords that should prevent subscription detection (salary, self-transfer…).
  final List<String> ignoreKeywords;

  // ── Parsing ───────────────────────────────────────────────────────────────

  factory SmsRuleFile.fromJson(Map<String, dynamic> json) {
    final subRaw = json['subscriptionDetection'];
    return SmsRuleFile(
      version: (json['version'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as String?) ?? '',
      includeKeywords: _stringList(json['includeKeywords']),
      excludeKeywords: _stringList(json['excludeKeywords']),
      categoryKeywords: _stringMap(json['categoryKeywords']),
      debitPatterns: _stringList(json['debitPatterns']),
      creditPatterns: _stringList(json['creditPatterns']),
      merchantPatterns: _stringList(json['merchantPatterns']),
      subscriptionDetection: subRaw is Map<String, dynamic>
          ? SubscriptionDetectionConfig.fromJson(subRaw)
          : SubscriptionDetectionConfig.defaults,
      subscriptionMerchants: _stringList(json['subscriptionMerchants']),
      ignoreKeywords: _stringList(json['ignoreKeywords']),
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
        'subscriptionDetection': subscriptionDetection.toJson(),
        'subscriptionMerchants': subscriptionMerchants,
        'ignoreKeywords': ignoreKeywords,
      };

  String toJsonString() => jsonEncode(toJson());

  // ── Compiled regex accessors (lazy, cached per instance) ──────────────────

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
      'categories=${categoryKeywords.length}, '
      'subMerchants=${subscriptionMerchants.length})';
}
