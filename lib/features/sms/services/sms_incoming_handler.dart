// ignore_for_file: avoid_print

import 'package:another_telephony/telephony.dart' as tel;

import '../models/sms_message.dart';
import '../utils/sms_logger.dart';
import 'android_sms_service.dart';

/// Processes incoming telephony SMS → parse → DB.
class SmsIncomingHandler {
  SmsIncomingHandler._();

  static final SmsIncomingHandler instance = SmsIncomingHandler._();

  final AndroidSmsService _service = AndroidSmsService();

  /// Called after a transaction is saved to refresh UI.
  Future<void> Function()? onTransactionSaved;

  /// Raw telephony callback — logs, parses, saves.
  Future<void> handleTelephonyMessage(tel.SmsMessage message) async {
    print('[SMS] RECEIVED');
    print('[SMS] From: ${message.address}');
    print('[SMS] Body: ${message.body}');

    final mapped = _map(message);
    if (mapped.body.trim().isEmpty) {
      SmsLogger.sms('Ignoring empty SMS body');
      return;
    }

    final saved = await _service.handleMessage(mapped);
    if (saved != null) {
      print('[SMS] Expense saved: ₹${saved.amount} ${saved.merchant}');
      await onTransactionSaved?.call();
    }
  }

  SmsMessage _map(tel.SmsMessage row) {
    final millis = _readMillis(row.date);
    return SmsMessage(
      body: row.body ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(millis),
      sender: row.address ?? 'Unknown',
    );
  }

  int _readMillis(Object? rawDate) {
    if (rawDate == null) return 0;
    if (rawDate is int) return rawDate;
    return int.tryParse(rawDate.toString()) ?? 0;
  }
}
