import '../models/sms_rule_file.dart';
import 'sms_logger.dart';

/// Returns true when an SMS body looks like a financial transaction.
///
/// When [rules] is supplied the include/exclude keyword lists from the rule
/// file are used; otherwise the hardcoded fallback lists are used.
/// This ensures the filter always works — even before [SmsRuleRepository]
/// has finished loading.
bool isRelevantTransactionSms(
  String body, {
  SmsRuleFile? rules,
  bool logRejections = true,
}) {
  final lower = body.toLowerCase().trim();
  if (lower.isEmpty) {
    if (logRejections) {
      SmsLogger.parser('No transaction detected — empty message');
    }
    return false;
  }

  final excludeList = rules?.excludeKeywords ?? smsExcludeKeywords;
  final includeList = rules?.includeKeywords ?? smsIncludeKeywords;

  for (final keyword in excludeList) {
    if (lower.contains(keyword)) {
      if (logRejections) {
        SmsLogger.parser(
          'No transaction detected — excluded keyword: "$keyword"',
        );
      }
      return false;
    }
  }

  final hasInclude = includeList.any(lower.contains);
  if (!hasInclude) {
    if (logRejections) {
      SmsLogger.parser(
        'No transaction detected — missing transaction keyword '
        '(${includeList.join("/")})',
      );
    }
    return false;
  }

  return true;
}

// ── Hardcoded fallback lists (used when rules have not loaded yet) ────────────

const List<String> smsIncludeKeywords = <String>[
  'debited',
  'credited',
  'spent',
  'withdrawn',
  'paid',
];

const List<String> smsExcludeKeywords = <String>[
  'otp',
  'one time password',
  'verification code',
  'do not share',
  'offer',
  'cashback offer',
  'pre-approved',
  'loan offer',
  'click here',
  'unsubscribe',
  'balance is',
  'available balance',
  'avl bal',
  'a/c bal',
  'account balance',
  'mini statement',
];
