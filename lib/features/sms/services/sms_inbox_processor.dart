import 'package:flutter/foundation.dart';

import 'sms_parser.dart';
import 'sms_service.dart';
import 'sms_transaction_processor.dart';

/// Orchestrates: fetch → filter → parse → dedupe → DB.
class SmsInboxProcessor {
  SmsInboxProcessor({
    required SmsService smsService,
    SmsParser? parser,
    SmsTransactionProcessor? processor,
  })  : _smsService = smsService,
        _parser = parser ?? SmsParser(),
        _processor = processor ?? SmsTransactionProcessor();

  final SmsService _smsService;
  final SmsParser _parser;
  final SmsTransactionProcessor _processor;

  Future<SmsProcessResult> processSmsTransactions() async {
    final messages = await _smsService.fetchMessages();
    var inserted = 0;
    var skipped = 0;
    var duplicates = 0;

    debugPrint('[SMS] processSmsTransactions count=${messages.length}');

    for (final sms in messages) {
      debugPrint('Processing SMS: ${sms.body}');
      final parsed = _parser.parse(sms);
      if (parsed == null) {
        debugPrint('Skipped SMS');
        skipped++;
        continue;
      }
      debugPrint('Parsed: $parsed');

      if (await _processor.saveIfNew(parsed)) {
        inserted++;
      } else {
        debugPrint('Duplicate detected');
        duplicates++;
      }
    }

    return SmsProcessResult(
      inserted: inserted,
      skipped: skipped,
      duplicates: duplicates,
      total: messages.length,
    );
  }
}

class SmsProcessResult {
  const SmsProcessResult({
    required this.inserted,
    required this.skipped,
    required this.duplicates,
    required this.total,
  });

  final int inserted;
  final int skipped;
  final int duplicates;
  final int total;
}
