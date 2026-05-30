import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import 'sms_logger.dart';

/// Runtime SMS permissions (Android only).
class SmsPermissions {
  const SmsPermissions();

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<bool> requestSmsPermissions() async {
    if (!isAndroid) {
      SmsLogger.permission('Skipped — not Android');
      return false;
    }

    SmsLogger.permission('SMS Permission Requested');
    print('[SMS] Requesting permission...');

    final sms = await Permission.sms.request();
    print('[SMS] Permission status: $sms');
    SmsLogger.permission('READ_SMS result: ${sms.isGranted ? "granted" : "denied"} ($sms)');

    if (!sms.isGranted) {
      return false;
    }

    final phone = await Permission.phone.request();
    SmsLogger.permission(
      'READ_PHONE_STATE result: ${phone.isGranted ? "granted" : "denied"} ($phone)',
    );

    return sms.isGranted;
  }

  Future<bool> hasSmsPermission() async {
    if (!isAndroid) return false;
    final granted = await Permission.sms.isGranted;
    SmsLogger.permission('hasSmsPermission: $granted');
    return granted;
  }
}
