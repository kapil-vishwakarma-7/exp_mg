import 'sms_logger.dart';

/// Returns null when SMS should be skipped; logs the reason via [SmsLogger].
bool isRelevantTransactionSms(String body, {bool logRejections = true}) {
  final lower = body.toLowerCase().trim();
  if (lower.isEmpty) {
    if (logRejections) {
      SmsLogger.parser('No transaction detected — empty message');
    }
    return false;
  }

  for (final keyword in smsExcludeKeywords) {
    if (lower.contains(keyword)) {
      if (logRejections) {
        SmsLogger.parser(
          'No transaction detected — excluded keyword: "$keyword"',
        );
      }
      return false;
    }
  }

  final hasInclude = smsIncludeKeywords.any(lower.contains);
  if (!hasInclude) {
    if (logRejections) {
      SmsLogger.parser(
        'No transaction detected — missing transaction keyword '
        '(debited/credited/spent/withdrawn/paid)',
      );
    }
    return false;
  }

  return true;
}

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
