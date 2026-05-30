// ignore_for_file: avoid_print — intentional raw SMS debug output

import 'dart:io' show Platform;

import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sms_incoming_handler.dart';

/// Starts SMS permission + foreground listener at app launch.
Future<void> bootstrapSmsDebugListener() async {
  print('[SMS] App initialized and ready to receive SMS');

  if (!Platform.isAndroid) {
    print('[SMS] Bootstrap skipped — not Android');
    return;
  }

  print('[SMS] Requesting permission...');
  final status = await Permission.sms.request();
  print('[SMS] Permission status: $status');

  if (!status.isGranted) {
    print('[SMS] Permission NOT granted — SMS will NOT be received');
    return;
  }

  final telephony = Telephony.instance;

  print('[SMS] Requesting telephony phone+SMS permissions...');
  final telephonyGranted = await telephony.requestPhoneAndSmsPermissions;
  print('[SMS] Telephony permission: ${telephonyGranted == true ? "granted" : "denied"}');

  print('[SMS] Starting listener...');

  telephony.listenIncomingSms(
    onNewMessage: SmsIncomingHandler.instance.handleTelephonyMessage,
    listenInBackground: false,
  );

  print('[SMS] Listener registered (foreground only — keep app OPEN)');
}
