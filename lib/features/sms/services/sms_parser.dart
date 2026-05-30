import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import '../utils/sms_category_detector.dart';
import '../utils/sms_date_time_parser.dart';
import '../utils/sms_filter.dart';
import '../utils/sms_logger.dart';

/// India-focused bank/UPI SMS parser.
class SmsParser {
  static final List<RegExp> _debitAmountPatterns = <RegExp>[
    RegExp(
      r'(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)\s+debited',
      caseSensitive: false,
    ),
    RegExp(
      r'spent\s+(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)\s+paid',
      caseSensitive: false,
    ),
    RegExp(
      r'paid\s+(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)\s+withdrawn',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _creditAmountPatterns = <RegExp>[
    RegExp(
      r'(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)\s+credited',
      caseSensitive: false,
    ),
    RegExp(
      r'received\s+(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)\s+received',
      caseSensitive: false,
    ),
  ];

  static final RegExp _genericAmount = RegExp(
    r'(?:INR|Rs\.?|₹)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _accountPattern = RegExp(
    r'(?:A/c|Acct|account|a/c)\s?[Xx*]*(\d{4})',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:Bal|Balance|avl\s+bal)[:\s]+(?:INR|Rs\.?|₹)?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final List<RegExp> _merchantPatterns = <RegExp>[
    RegExp(r'Info:\s*([A-Za-z0-9@._ ]+)', caseSensitive: false),
    RegExp(
      r'\bat\s+([A-Za-z0-9@._]+)(?:\s+on|\s+via|\.)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:INR|Rs\.?|₹)\s?[\d,.]+\s+paid\s+to\s+([A-Za-z0-9@._ ]+)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bto\s+([A-Za-z0-9@._ ]+?)(?:\s+via|\s+@|\.)',
      caseSensitive: false,
    ),
    RegExp(r'via\s+UPI\s+to\s+([A-Za-z0-9@._ ]+)', caseSensitive: false),
    RegExp(
      r'UPI\s+txn\s+of\s+(?:INR|Rs\.?|₹)?\s?[\d,.]+\s+to\s+([A-Za-z0-9@._ ]+)',
      caseSensitive: false,
    ),
  ];

  ParsedTransaction? parse(SmsMessage sms) {
    SmsLogger.parser('Parsing SMS: ${sms.body}');

    try {
      if (!isRelevantTransactionSms(sms.body)) return null;

      final body = sms.body.trim();
      final lower = body.toLowerCase();

      final amountResult = _extractAmount(body, lower);
      if (amountResult.value == null || amountResult.value! <= 0) {
        SmsLogger.parser('No transaction detected — amount not found');
        return null;
      }

      final typeResult = amountResult.type ?? _inferTypeFromKeywords(lower);
      if (typeResult == null) {
        SmsLogger.parser('No transaction detected — type unknown');
        return null;
      }
      SmsLogger.parser('Matched $typeResult pattern: ${amountResult.patternName}');

      final merchant = _extractMerchant(body, lower);
      final account = _extractAccount(body);
      final balance = _extractBalance(body);
      final transactionTime = SmsDateTimeParser.resolve(
        body: body,
        smsTimestamp: sms.date,
      );

      SmsLogger.parser('Time detected: $transactionTime');
      SmsLogger.parser(
        'Type: $typeResult | Amount: ${amountResult.value} | Merchant: $merchant',
      );

      final parsed = ParsedTransaction(
        amount: amountResult.value!,
        type: typeResult,
        merchant: merchant,
        category: detectSmsCategory(merchant, messageBody: body),
        transactionTime: transactionTime,
        rawSms: body,
        account: account,
        balance: balance,
      );

      SmsLogger.parser('Parsed Result: ${parsed.toLogMap()}');
      return parsed;
    } catch (error, stackTrace) {
      SmsLogger.parser('No transaction detected — $error');
      SmsLogger.parser('$stackTrace');
      return null;
    }
  }

  _AmountResult _extractAmount(String body, String lower) {
    for (var i = 0; i < _creditAmountPatterns.length; i++) {
      final match = _creditAmountPatterns[i].firstMatch(body);
      if (match == null) continue;
      final value = _parseAmountGroup(match.group(1));
      if (value != null) {
        return _AmountResult(value: value, type: 'credit', patternName: 'credit_$i');
      }
    }

    for (var i = 0; i < _debitAmountPatterns.length; i++) {
      final match = _debitAmountPatterns[i].firstMatch(body);
      if (match == null) continue;
      final value = _parseAmountGroup(match.group(1));
      if (value != null) {
        return _AmountResult(value: value, type: 'debit', patternName: 'debit_$i');
      }
    }

    final generic = _genericAmount.firstMatch(body);
    if (generic != null) {
      final value = _parseAmountGroup(generic.group(1));
      if (value != null) {
        final type = _inferTypeFromKeywords(lower);
        if (type != null) {
          return _AmountResult(value: value, type: type, patternName: 'generic');
        }
      }
    }

    return const _AmountResult();
  }

  String? _inferTypeFromKeywords(String lower) {
    const debitWords = <String>['debited', 'spent', 'withdrawn', 'paid'];
    const creditWords = <String>['credited', 'received'];
    final hasDebit = debitWords.any(lower.contains);
    final hasCredit = creditWords.any(lower.contains);
    if (hasCredit && !hasDebit) return 'credit';
    if (hasDebit) return 'debit';
    if (hasCredit) return 'credit';
    return null;
  }

  double? _parseAmountGroup(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', '').trim());
  }

  String? _extractAccount(String body) {
    return _accountPattern.firstMatch(body)?.group(1);
  }

  double? _extractBalance(String body) {
    final match = _balancePattern.firstMatch(body);
    if (match == null) return null;
    return _parseAmountGroup(match.group(1));
  }

  String _extractMerchant(String body, String lower) {
    if (lower.contains('upi') ||
        lower.contains('vpa') ||
        lower.contains('@okaxis') ||
        lower.contains('@ybl') ||
        lower.contains('@upi')) {
      SmsLogger.parser('UPI transaction detected');
    }

    for (var i = 0; i < _merchantPatterns.length; i++) {
      final match = _merchantPatterns[i].firstMatch(body);
      if (match == null) continue;
      final merchant = _cleanMerchant(match.group(1) ?? '');
      if (merchant != 'Unknown') {
        SmsLogger.parser('Merchant pattern $i matched');
        return merchant;
      }
    }
    return 'Unknown';
  }

  String _cleanMerchant(String value) {
    var cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+on\s+\d{1,2}.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+via\s+.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'[\.\s]+(?:bal|balance).*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'@(?:okaxis|ybl|upi).*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^A-Za-z0-9@._ ]'), '').trim();
    if (cleaned.length > 40) cleaned = cleaned.substring(0, 40).trim();
    return cleaned.isEmpty ? 'Unknown' : cleaned;
  }
}

class _AmountResult {
  const _AmountResult({this.value, this.type, this.patternName});

  final double? value;
  final String? type;
  final String? patternName;
}
