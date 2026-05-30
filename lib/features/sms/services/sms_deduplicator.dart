import '../../expenses/database/database_helper.dart';
import '../models/parsed_transaction.dart';
import '../utils/sms_logger.dart';

class SmsDeduplicator {
  SmsDeduplicator({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<bool> isDuplicate(ParsedTransaction transaction) async {
    final exists = await _db.smsHashExists(transaction.dedupeKey);
    if (exists) {
      SmsLogger.db(
        'Duplicate hash detected: ${transaction.dedupeKey}',
      );
    }
    return exists;
  }
}
