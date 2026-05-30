import '../../models/sms_message.dart';

/// No-op SMS platform used on iOS, macOS, web, and desktop.
class SmsPlatform {
  bool get isAndroid => false;

  Future<bool> requestPermissions() async => false;

  Future<List<SmsMessage>> readInbox() async => const <SmsMessage>[];

  Stream<SmsMessage> listenIncoming() => const Stream<SmsMessage>.empty();

  Future<void> startListening(void Function(SmsMessage) onMessage) async {}

  Future<void> stopListening() async {}
}
