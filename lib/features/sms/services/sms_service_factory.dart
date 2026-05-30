import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'android_sms_service.dart';
import 'noop_sms_service.dart';
import 'sms_service.dart';

/// Creates platform-appropriate [SmsService] (Android vs no-op).
SmsService createSmsService() {
  if (!kIsWeb && Platform.isAndroid) {
    return AndroidSmsService();
  }
  return NoopSmsService();
}
