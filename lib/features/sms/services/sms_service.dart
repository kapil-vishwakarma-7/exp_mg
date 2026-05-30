import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';

/// Abstraction for SMS sources (inbox + live stream).
abstract class SmsService {
  /// Whether SMS APIs are available on this platform (Android only).
  bool get isSupported;

  Future<bool> requestPermissions();

  Future<List<SmsMessage>> fetchMessages();

  /// Live incoming SMS while tracking is enabled.
  Stream<SmsMessage> get incomingMessages;

  Future<void> startListening();

  Future<void> stopListening();

  /// Parses and persists a single message; returns null if skipped/duplicate.
  Future<ParsedTransaction?> handleMessage(SmsMessage message);
}
