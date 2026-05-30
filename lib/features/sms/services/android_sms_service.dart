import 'dart:async';
import 'dart:io' show Platform;

import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import '../utils/sms_logger.dart';
import '../utils/sms_permissions.dart';
import 'platform/sms_platform_factory.dart' show createSmsPlatform;
import 'platform/sms_platform_stub.dart';
import 'sms_parser.dart';
import 'sms_service.dart';
import 'sms_transaction_processor.dart';

/// Android-only SMS service: inbox read + live listener.
class AndroidSmsService implements SmsService {
  AndroidSmsService({
    SmsPlatform? platform,
    SmsParser? parser,
    SmsTransactionProcessor? processor,
    SmsPermissions? permissions,
  })  : _platform = platform ?? createSmsPlatform(),
        _parser = parser ?? SmsParser(),
        _processor = processor ?? SmsTransactionProcessor(),
        _permissions = permissions ?? const SmsPermissions();

  final SmsPlatform _platform;
  final SmsParser _parser;
  final SmsTransactionProcessor _processor;
  final SmsPermissions _permissions;
  final StreamController<SmsMessage> _incoming =
      StreamController<SmsMessage>.broadcast();

  SmsMessage? lastReceivedSms;
  SmsHandleOutcome? lastOutcome;

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Stream<SmsMessage> get incomingMessages => _incoming.stream;

  @override
  Future<bool> requestPermissions() async {
    if (!isSupported) {
      SmsLogger.sms('requestPermissions skipped — not Android');
      return false;
    }
    SmsLogger.sms('Requesting SMS permissions…');
    final handlerOk = await _permissions.requestSmsPermissions();
    if (!handlerOk) {
      SmsLogger.sms('Permission denied via permission_handler');
      return false;
    }
    final telephonyOk = await _platform.requestPermissions();
    if (!telephonyOk) {
      SmsLogger.sms('Permission denied via telephony');
    }
    return telephonyOk;
  }

  @override
  Future<List<SmsMessage>> fetchMessages() async {
    if (!isSupported) return const <SmsMessage>[];
    return _platform.readInbox();
  }

  @override
  Future<void> startListening() async {
    if (!isSupported) return;
    await _platform.startListening(_onIncoming);
  }

  @override
  Future<void> stopListening() async {
    await _platform.stopListening();
  }

  void _onIncoming(SmsMessage message) {
    if (_incoming.isClosed) return;
    _incoming.add(message);
    unawaited(handleMessage(message));
  }

  @override
  Future<ParsedTransaction?> handleMessage(SmsMessage message) async {
    lastReceivedSms = message;
    SmsLogger.sms(
      'Processing SMS -> From: ${message.sender} | Body: ${message.body}',
    );

    try {
      final parsed = _parser.parse(message);
      if (parsed == null) {
        lastOutcome = const SmsHandleOutcome(
          stage: 'parse_failed',
          detail: 'See [PARSER] logs above',
        );
        SmsLogger.sms('Skipped SMS — no transaction detected');
        return null;
      }

      SmsLogger.sms('Saving transaction: ${parsed.toLogMap()}');
      final saved = await _processor.saveIfNew(parsed);
      if (!saved) {
        lastOutcome = const SmsHandleOutcome(
          stage: 'duplicate',
          detail: 'Hash already exists in DB',
        );
        SmsLogger.sms('Duplicate detected — not saved');
        return null;
      }

      lastOutcome = SmsHandleOutcome(stage: 'saved', transaction: parsed);
      SmsLogger.sms('Transaction saved successfully');
      return parsed;
    } catch (error, stackTrace) {
      lastOutcome = SmsHandleOutcome(
        stage: 'error',
        detail: error.toString(),
      );
      SmsLogger.sms('Error saving transaction: $error');
      SmsLogger.sms('$stackTrace');
      return null;
    }
  }

  Future<void> dispose() async {
    await stopListening();
    await _incoming.close();
  }
}
