import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import '../models/sms_rule_file.dart';
import '../utils/sms_category_detector.dart';
import '../utils/sms_date_time_parser.dart';
import '../utils/sms_filter.dart';
import '../utils/sms_logger.dart';
import '../../expenses/models/expense.dart' show ConfirmationStatus, ConfidenceScore;
import 'sms_rule_repository.dart';

/// India-focused bank/UPI SMS parser.
///
/// Regex patterns and keyword lists are driven by [SmsRuleFile] loaded from
/// [SmsRuleRepository].  The parser automatically picks up updated rules
/// whenever [SmsRuleRepository] swaps them in — no restart required.
class SmsParser {
  SmsParser({SmsRuleRepository? repository})
      : _repo = repository ?? SmsRuleRepository.instance;

  final SmsRuleRepository _repo;

  /// Convenience getter — always returns the current live rules.
  SmsRuleFile get _rules => _repo.rules;

  // ── Static fallback patterns (used only if rules have no patterns) ────────

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

  // ── Public API ────────────────────────────────────────────────────────────

  ParsedTransaction? parse(SmsMessage sms) {
    SmsLogger.parser('Parsing SMS: ${sms.body}');

    try {
      // Filter uses live rules from the repository.
      if (!isRelevantTransactionSms(sms.body, rules: _rules)) return null;

      final body = sms.body.trim();
      final lower = body.toLowerCase();

      final amountResult = _extractAmount(body, lower);
      if (amountResult.value == null || amountResult.value! <= 0) {
        SmsLogger.parser('No transaction detected — amount not found');
        return null;
      }

      final typeResult =
          amountResult.type ?? _inferTypeFromKeywords(lower);
      if (typeResult == null) {
        SmsLogger.parser('No transaction detected — type unknown');
        return null;
      }
      SmsLogger.parser(
        'Matched $typeResult pattern: ${amountResult.patternName}',
      );

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

      // ── Subscription detection (Steps 1–4) ───────────────────────────
      // Step 1: rule-flagged via amountResult (future: per-rule is_subscription)
      // Step 2: keyword match in SMS body
      final subConfig = _rules.subscriptionDetection;
      final isSubKeyword = subConfig.keywords.any(lower.contains);

      // Step 3: normalise merchant (uppercase, trimmed)
      final normalisedMerchant = merchant.trim().toUpperCase();

      // Step 4: known subscription merchant list
      final isKnownSubMerchant = _rules.subscriptionMerchants
          .any(normalisedMerchant.toLowerCase().contains);

      final isSubscription = isSubKeyword || isKnownSubMerchant;

      if (isSubscription) {
        SmsLogger.parser(
          '[SUB] Flagged as subscription — '
          'keyword=$isSubKeyword known=$isKnownSubMerchant',
        );
      }

      // ── Confidence score ──────────────────────────────────────────────
      // high   : named pattern matched + known merchant/subscription
      // medium : named pattern matched (debit/credit specific)
      // low    : generic fallback pattern used
      final String confidence;
      if (amountResult.patternName != 'generic' &&
          (isKnownSubMerchant ||
              _rules.categoryKeywords.containsKey(merchant.toLowerCase()))) {
        confidence = ConfidenceScore.high;
      } else if (amountResult.patternName != 'generic') {
        confidence = ConfidenceScore.medium;
      } else {
        confidence = ConfidenceScore.low;
      }

      // ── Confirmation status ───────────────────────────────────────────
      // Confirmed immediately when:  high confidence  OR  merchant is trusted
      // Otherwise goes to pending review.
      // Trust check is async — fire-and-forget; default to pending for safety.
      // The ConfirmationService will auto-confirm after trust lookup.
      final String confirmStatus;
      if (confidence == ConfidenceScore.high) {
        confirmStatus = ConfirmationStatus.confirmed;
      } else {
        // Will be upgraded to confirmed by ConfirmationService if trusted.
        confirmStatus = ConfirmationStatus.pending;
      }

      SmsLogger.parser(
        '[CONFIRM] confidence=$confidence status=$confirmStatus',
      );

      final parsed = ParsedTransaction(
        amount: amountResult.value!,
        type: typeResult,
        merchant: merchant,
        category: detectSmsCategory(
          merchant,
          messageBody: body,
          rules: _rules,
        ),
        transactionTime: transactionTime,
        rawSms: body,
        account: account,
        balance: balance,
        isSubscription: isSubscription,
        confidenceScore: confidence,
        confirmationStatus: confirmStatus,
      );

      SmsLogger.parser('Parsed Result: ${parsed.toLogMap()}');
      return parsed;
    } catch (error, stackTrace) {
      SmsLogger.parser('No transaction detected — $error');
      SmsLogger.parser('$stackTrace');
      return null;
    }
  }

  // ── Amount extraction ─────────────────────────────────────────────────────

  _AmountResult _extractAmount(String body, String lower) {
    final creditPatterns = _rules.compiledCreditPatterns;
    for (var i = 0; i < creditPatterns.length; i++) {
      final match = creditPatterns[i].firstMatch(body);
      if (match == null) continue;
      final value = _parseAmountGroup(match.group(1));
      if (value != null) {
        return _AmountResult(
          value: value,
          type: 'credit',
          patternName: 'credit_$i',
        );
      }
    }

    final debitPatterns = _rules.compiledDebitPatterns;
    for (var i = 0; i < debitPatterns.length; i++) {
      final match = debitPatterns[i].firstMatch(body);
      if (match == null) continue;
      final value = _parseAmountGroup(match.group(1));
      if (value != null) {
        return _AmountResult(
          value: value,
          type: 'debit',
          patternName: 'debit_$i',
        );
      }
    }

    // Generic fallback — any currency amount in the message.
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
    // Use live rules so new debit/credit keywords work without code changes.
    final debitWords = _rules.includeKeywords
        .where((k) => const ['debited', 'spent', 'withdrawn', 'paid'].contains(k))
        .toList();
    final creditWords = _rules.includeKeywords
        .where((k) => const ['credited', 'received'].contains(k))
        .toList();

    // Fall back to hardcoded sets if rules don't include them (safe guard).
    final effectiveDebit = debitWords.isEmpty
        ? const <String>['debited', 'spent', 'withdrawn', 'paid']
        : debitWords;
    final effectiveCredit =
        creditWords.isEmpty ? const <String>['credited', 'received'] : creditWords;

    final hasDebit = effectiveDebit.any(lower.contains);
    final hasCredit = effectiveCredit.any(lower.contains);

    if (hasCredit && !hasDebit) return 'credit';
    if (hasDebit) return 'debit';
    if (hasCredit) return 'credit';
    return null;
  }

  double? _parseAmountGroup(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', '').trim());
  }

  // ── Account & balance extraction (static patterns — rarely change) ────────

  String? _extractAccount(String body) =>
      _accountPattern.firstMatch(body)?.group(1);

  double? _extractBalance(String body) {
    final match = _balancePattern.firstMatch(body);
    if (match == null) return null;
    return _parseAmountGroup(match.group(1));
  }

  // ── Merchant extraction ───────────────────────────────────────────────────

  String _extractMerchant(String body, String lower) {
    if (lower.contains('upi') ||
        lower.contains('vpa') ||
        lower.contains('@okaxis') ||
        lower.contains('@ybl') ||
        lower.contains('@upi')) {
      SmsLogger.parser('UPI transaction detected');
    }

    final patterns = _rules.compiledMerchantPatterns;
    for (var i = 0; i < patterns.length; i++) {
      final match = patterns[i].firstMatch(body);
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

// ── Internal result type ──────────────────────────────────────────────────────

class _AmountResult {
  const _AmountResult({this.value, this.type, this.patternName});

  final double? value;
  final String? type;
  final String? patternName;
}
