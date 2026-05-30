import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'sms_platform_android.dart';
import 'sms_platform_stub.dart';

/// Returns Android telephony bridge or a no-op stub (iOS / macOS / web).
SmsPlatform createSmsPlatform() {
  if (kIsWeb || !Platform.isAndroid) {
    return SmsPlatform();
  }
  return AndroidSmsPlatform();
}
