import 'package:flutter/foundation.dart';

import '../models/parsed_transaction.dart';

/// Tagged console logs for SMS debugging.
class SmsLogger {
  static void sms(String message) => debugPrint('[SMS] $message');

  static void parser(String message) => debugPrint('[PARSER] $message');

  static void db(String message) => debugPrint('[DB] $message');

  static void permission(String message) =>
      debugPrint('[SMS][PERMISSION] $message');
}

/// Outcome of processing one SMS through parse + save.
class SmsHandleOutcome {
  const SmsHandleOutcome({
    required this.stage,
    this.transaction,
    this.detail,
  });

  /// received | filtered | parse_failed | duplicate | saving | saved | error
  final String stage;
  final ParsedTransaction? transaction;
  final String? detail;

  bool get saved => stage == 'saved';
}
