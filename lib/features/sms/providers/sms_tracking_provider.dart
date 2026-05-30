import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parsed_transaction.dart';
import '../models/sms_message.dart';
import '../services/android_sms_service.dart';
import '../services/sms_service.dart';
import '../services/sms_service_factory.dart';
import '../utils/sms_logger.dart';

/// Manages "Enable SMS Tracking" toggle and Android SMS pipeline.
class SmsTrackingProvider extends ChangeNotifier {
  SmsTrackingProvider({SmsService? smsService})
      : _smsService = smsService ?? createSmsService();

  static const String _prefKey = 'sms_tracking_enabled';

  final SmsService _smsService;
  StreamSubscription<SmsMessage>? _subscription;

  bool _enabled = false;
  bool _busy = false;
  String? _statusMessage;
  int _inboxCount = 0;
  SmsMessage? _lastReceivedSms;
  String? _lastFailureReason;
  final List<ParsedTransaction> _recentParsed = <ParsedTransaction>[];

  bool get isSupported =>
      !kIsWeb && Platform.isAndroid && _smsService.isSupported;
  bool get isEnabled => _enabled;
  bool get isBusy => _busy;
  String? get statusMessage => _statusMessage;
  int get inboxCount => _inboxCount;
  SmsMessage? get lastReceivedSms => _lastReceivedSms;
  String? get lastFailureReason => _lastFailureReason;
  List<ParsedTransaction> get recentParsed =>
      List<ParsedTransaction>.unmodifiable(_recentParsed);

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
    notifyListeners();

    if (_enabled && isSupported) {
      await enableTracking();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!isSupported) {
      _statusMessage = 'SMS tracking is only available on Android';
      notifyListeners();
      return;
    }

    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    notifyListeners();

    if (value) {
      await enableTracking();
    } else {
      await disableTracking();
    }
  }

  Future<void> enableTracking() async {
    if (!isSupported) return;

    _busy = true;
    _statusMessage = 'Requesting SMS permissions…';
    notifyListeners();

    SmsLogger.sms('enableTracking started');

    final granted = await _smsService.requestPermissions();
    if (!granted) {
      _enabled = false;
      _busy = false;
      _statusMessage = 'SMS permission denied';
      _lastFailureReason = 'Permission denied';
      SmsLogger.sms('enableTracking aborted — permission denied');
      notifyListeners();
      return;
    }

    _statusMessage = 'Reading inbox…';
    notifyListeners();

    final inbox = await _smsService.fetchMessages();
    _inboxCount = inbox.length;
    SmsLogger.sms('Processing $_inboxCount inbox message(s)…');

    for (final message in inbox) {
      await _processMessage(message, source: 'inbox');
    }

    await _smsService.startListening();
    _subscription ??=
        _smsService.incomingMessages.listen((msg) {
      unawaited(_processMessage(msg, source: 'live'));
    });

    _busy = false;
    _statusMessage = 'SMS tracking active ($_inboxCount inbox scanned)';
    SmsLogger.sms('enableTracking complete — listener active');
    notifyListeners();
  }

  Future<void> disableTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    await _smsService.stopListening();
    _statusMessage = 'SMS tracking disabled';
    SmsLogger.sms('Tracking disabled');
    notifyListeners();
  }

  Future<void> _processMessage(
    SmsMessage message, {
    required String source,
  }) async {
    _lastReceivedSms = message;
    _lastFailureReason = null;
    SmsLogger.sms('[$source] Received for processing: ${message.body}');
    notifyListeners();

    final saved = await _smsService.handleMessage(message);

    if (_smsService is AndroidSmsService) {
      final android = _smsService;
      _lastReceivedSms = android.lastReceivedSms ?? message;
      final outcome = android.lastOutcome;
      if (outcome != null && !outcome.saved) {
        _lastFailureReason = '${outcome.stage}: ${outcome.detail ?? ""}';
      }
    }

    if (saved == null) {
      notifyListeners();
      return;
    }

    _recentParsed.insert(0, saved);
    if (_recentParsed.length > 20) {
      _recentParsed.removeRange(20, _recentParsed.length);
    }
    _lastFailureReason = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disableTracking());
    super.dispose();
  }
}
