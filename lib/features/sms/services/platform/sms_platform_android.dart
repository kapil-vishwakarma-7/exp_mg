import 'package:another_telephony/telephony.dart' as tel;

import '../../models/sms_message.dart';
import '../../utils/sms_logger.dart';
import 'sms_platform_stub.dart';

/// Android-only telephony bridge. Not imported on web.
class AndroidSmsPlatform extends SmsPlatform {
  AndroidSmsPlatform({tel.Telephony? telephony})
      : _telephony = telephony ?? tel.Telephony.instance;

  final tel.Telephony _telephony;
  void Function(SmsMessage message)? _onMessage;

  @override
  bool get isAndroid => true;

  @override
  Future<bool> requestPermissions() async {
    SmsLogger.permission('Telephony permission request');
    final granted = await _telephony.requestPhoneAndSmsPermissions;
    SmsLogger.permission(
      'Telephony result: ${granted == true ? "granted" : "denied"}',
    );
    return granted == true;
  }

  @override
  Future<List<SmsMessage>> readInbox() async {
    SmsLogger.sms('Reading inbox…');
    final rows = await _telephony.getInboxSms(
      columns: <tel.SmsColumn>[
        tel.SmsColumn.ADDRESS,
        tel.SmsColumn.BODY,
        tel.SmsColumn.DATE,
      ],
      sortOrder: <tel.OrderBy>[
        tel.OrderBy(tel.SmsColumn.DATE, sort: tel.Sort.DESC),
      ],
    );

    final messages =
        rows.map(_mapRow).where((m) => m.body.trim().isNotEmpty).toList();
    SmsLogger.sms('Inbox loaded: ${messages.length} message(s)');
    for (final msg in messages.take(5)) {
      SmsLogger.sms(
        'INBOX -> From: ${msg.sender} | Time: ${msg.date} | Body: ${msg.body}',
      );
    }
    if (messages.length > 5) {
      SmsLogger.sms('… and ${messages.length - 5} more inbox message(s)');
    }
    return messages;
  }

  @override
  Stream<SmsMessage> listenIncoming() {
    return const Stream<SmsMessage>.empty();
  }

  @override
  Future<void> startListening(void Function(SmsMessage) onMessage) async {
    _onMessage = onMessage;
    SmsLogger.sms('SMS Listener Started (foreground only — keep app open)');
    SmsLogger.sms(
      'Tip: adb emu sms send 111111 "INR 1200 debited at Swiggy" '
      'requires app in foreground for live listener',
    );

    _telephony.listenIncomingSms(
      onNewMessage: (tel.SmsMessage message) {
        print('[SMS] RECEIVED');
        print('[SMS] From: ${message.address}');
        print('[SMS] Body: ${message.body}');
        SmsLogger.sms(
          'SMS RECEIVED -> From: ${message.address ?? "Unknown"} | '
          'Body: ${message.body ?? ""}',
        );
        final mapped = _mapRow(message);
        SmsLogger.sms('SMS RECEIVED timestamp: ${mapped.date}');
        if (mapped.body.trim().isEmpty) {
          SmsLogger.sms('Ignoring empty SMS body');
          return;
        }
        _onMessage?.call(mapped);
      },
      listenInBackground: false,
    );
  }

  @override
  Future<void> stopListening() async {
    SmsLogger.sms('SMS Listener Stopped');
    _onMessage = null;
  }

  SmsMessage _mapRow(tel.SmsMessage row) {
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

SmsPlatform createSmsPlatform() {
  SmsLogger.sms('Using Android telephony platform');
  return AndroidSmsPlatform();
}
