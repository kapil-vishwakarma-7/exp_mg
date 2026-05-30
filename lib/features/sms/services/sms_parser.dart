import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import '../utils/sms_category_detector.dart';
import '../utils/sms_filter.dart';
import '../utils/sms_logger.dart';

/// India-focused bank/UPI SMS parser.
class SmsParser {
  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _amountFallback = RegExp(
    r'([\d,]+(?:\.\d{1,2})?)\s?(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accountPattern = RegExp(
    r'(?:a/c|ac|account)\s*(?:no\.?|number)?\s*(?:x{2,}|X{2,})?(\d{4})',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:bal(?:ance)?|avl(?:\s+bal)?)\s*[:\-]?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final List<RegExp> _merchantPatterns = <RegExp>[
    RegExp(r'\bat\s+([A-Za-z0-9&\.\-\s]{2,40})', caseSensitive: false),
    RegExp(r'\bto\s+([A-Za-z0-9&\.\-\s]{2,40})', caseSensitive: false),
    RegExp(
      r'via\s+upi\s+to\s+([A-Za-z0-9&\.\-\s]{2,40})',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:spent|paid)\s+(?:on|to|at)\s+([A-Za-z0-9&\.\-\s]{2,40})',
      caseSensitive: false,
    ),
  ];

  /// Returns null for irrelevant or malformed SMS (never throws).
  ParsedTransaction? parse(SmsMessage sms) {
    SmsLogger.parser('Parsing SMS: ${sms.body}');
    SmsLogger.parser('Sender: ${sms.sender} | Time: ${sms.date}');

    try {
      if (!isRelevantTransactionSms(sms.body)) {
        return null;
      }

      final body = sms.body.trim();
      final lower = body.toLowerCase();

      final amountResult = _extractAmount(body);
      if (amountResult.value == null || amountResult.value! <= 0) {
        SmsLogger.parser(
          'No transaction detected — ${amountResult.reason ?? "amount not found"}',
        );
        return null;
      }
      SmsLogger.parser('Amount detected: ${amountResult.value}');
      if (amountResult.patternName != null) {
        SmsLogger.parser('Matched amount pattern: ${amountResult.patternName}');
      }

      final typeResult = _detectType(lower);
      if (typeResult.value == null) {
        SmsLogger.parser(
          'No transaction detected — ${typeResult.reason ?? "debit/credit type unknown"}',
        );
        return null;
      }
      SmsLogger.parser('Matched ${typeResult.value} pattern');

      final merchantResult = _extractMerchant(body);
      final merchant = merchantResult.value ?? 'Unknown';
      SmsLogger.parser('Merchant detected: $merchant');
      if (merchantResult.patternName != null) {
        SmsLogger.parser(
          'Matched merchant pattern: ${merchantResult.patternName}',
        );
      }

      final account = _extractAccount(body);
      if (account != null) {
        SmsLogger.parser('Account detected: $account');
      }

      final balance = _extractBalance(body);
      if (balance != null) {
        SmsLogger.parser('Balance detected: $balance');
      }

      final parsed = ParsedTransaction(
        amount: amountResult.value!,
        type: typeResult.value!,
        merchant: merchant,
        category: detectSmsCategory(merchant),
        date: _resolveDate(body, sms.date),
        rawSms: body,
        account: account,
        balance: balance,
      );

      SmsLogger.parser('Parsed Result: ${parsed.toLogMap()}');
      return parsed;
    } catch (error, stackTrace) {
      SmsLogger.parser('No transaction detected — parse error: $error');
      SmsLogger.parser('$stackTrace');
      return null;
    }
  }

  _ParseField<double> _extractAmount(String body) {
    final primary = _amountPattern.firstMatch(body);
    if (primary != null) {
      final value = double.tryParse(primary.group(1)!.replaceAll(',', ''));
      if (value != null && value > 0) {
        return _ParseField(value: value, patternName: 'inr/rs prefix');
      }
    }

    final fallback = _amountFallback.firstMatch(body);
    if (fallback != null) {
      final value = double.tryParse(fallback.group(1)!.replaceAll(',', ''));
      if (value != null && value > 0) {
        return _ParseField(value: value, patternName: 'inr/rs suffix');
      }
    }

    return const _ParseField(reason: 'no amount regex match');
  }

  _ParseField<String> _detectType(String lower) {
    const debit = <String>['debited', 'spent', 'withdrawn', 'paid'];
    const credit = <String>['credited', 'received'];
    final debitHit = debit.where(lower.contains).toList();
    final creditHit = credit.where(lower.contains).toList();
    final hasDebit = debitHit.isNotEmpty;
    final hasCredit = creditHit.isNotEmpty;

    if (hasDebit && !hasCredit) {
      return _ParseField(value: 'debit', patternName: debitHit.first);
    }
    if (hasCredit && !hasDebit) {
      return _ParseField(value: 'credit', patternName: creditHit.first);
    }
    if (hasDebit) {
      return _ParseField(value: 'debit', patternName: debitHit.first);
    }
    return const _ParseField(reason: 'no debit/credit keyword');
  }

  String? _extractAccount(String body) {
    final match = _accountPattern.firstMatch(body);
    return match?.group(1);
  }

  double? _extractBalance(String body) {
    final match = _balancePattern.firstMatch(body);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  _ParseField<String> _extractMerchant(String body) {
    for (var i = 0; i < _merchantPatterns.length; i++) {
      final pattern = _merchantPatterns[i];
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final merchant = _cleanMerchant(match.group(1) ?? '');
      if (merchant != 'Unknown') {
        return _ParseField(
          value: merchant,
          patternName: 'merchant_pattern_$i',
        );
      }
    }
    return const _ParseField(value: 'Unknown', reason: 'no merchant regex match');
  }

  String _cleanMerchant(String value) {
    var cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+(?:via|ref|txn|bal|a/c|ac)\s+.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'[\.\s]+bal(?:ance)?.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[^A-Za-z0-9&\.\-\s]'), '').trim();
    if (cleaned.length > 40) cleaned = cleaned.substring(0, 40).trim();
    return cleaned.isEmpty ? 'Unknown' : cleaned;
  }

  DateTime _resolveDate(String body, DateTime smsDate) {
    return _extractInlineDate(body) ??
        DateTime(smsDate.year, smsDate.month, smsDate.day);
  }

  DateTime? _extractInlineDate(String body) {
    final slash = RegExp(r'(\d{2})[-/](\d{2})[-/](\d{4})').firstMatch(body);
    if (slash != null) {
      return DateTime(
        int.parse(slash.group(3)!),
        int.parse(slash.group(2)!),
        int.parse(slash.group(1)!),
      );
    }
    return null;
  }
}

class _ParseField<T> {
  const _ParseField({this.value, this.patternName, this.reason});

  final T? value;
  final String? patternName;
  final String? reason;
}
