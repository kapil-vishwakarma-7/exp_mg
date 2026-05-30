import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import 'sms_service.dart';

/// Safe fallback for iOS, macOS, web, and desktop.
class NoopSmsService implements SmsService {
  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<List<SmsMessage>> fetchMessages() async => const <SmsMessage>[];

  @override
  Stream<SmsMessage> get incomingMessages => const Stream<SmsMessage>.empty();

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<ParsedTransaction?> handleMessage(SmsMessage message) async => null;
}
