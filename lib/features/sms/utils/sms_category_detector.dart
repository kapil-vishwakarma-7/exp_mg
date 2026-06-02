import '../models/sms_rule_file.dart';

/// Detects a spending category from the merchant name and/or SMS body.
///
/// When [rules] is supplied the category keyword map from the rule file is
/// used; otherwise the hardcoded [smsCategoryKeywords] fallback is used.
String detectSmsCategory(
  String merchant, {
  String? messageBody,
  SmsRuleFile? rules,
}) {
  final body = messageBody?.toLowerCase() ?? '';
  if (body.contains('atm') || body.contains('withdrawn')) return 'Cash';

  final keywordMap = rules?.categoryKeywords ?? smsCategoryKeywords;
  final lower = merchant.toLowerCase();

  for (final entry in keywordMap.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return 'Others';
}

// ── Hardcoded fallback map (used when rules have not loaded yet) ──────────────

const Map<String, String> smsCategoryKeywords = <String, String>{
  'swiggy': 'Food',
  'zomato': 'Food',
  'dominos': 'Food',
  'amazon': 'Shopping',
  'flipkart': 'Shopping',
  'myntra': 'Shopping',
  'uber': 'Travel',
  'ola': 'Travel',
  'netflix': 'Entertainment',
  'hotstar': 'Entertainment',
};
