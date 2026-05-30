import '../../expenses/database/database_helper.dart';
import '../models/parsed_transaction.dart';
import '../utils/sms_logger.dart';
import 'sms_deduplicator.dart';

class SmsTransactionProcessor {
  SmsTransactionProcessor({
    DatabaseHelper? databaseHelper,
    SmsDeduplicator? deduplicator,
  })  : _db = databaseHelper ?? DatabaseHelper.instance,
        _deduplicator = deduplicator ??
            SmsDeduplicator(databaseHelper: databaseHelper);

  final DatabaseHelper _db;
  final SmsDeduplicator _deduplicator;

  Future<bool> saveIfNew(ParsedTransaction transaction) async {
    SmsLogger.db('Checking duplicate before save…');
    if (await _deduplicator.isDuplicate(transaction)) {
      return false;
    }

    SmsLogger.db('Saving transaction: ${transaction.toLogMap()}');
    try {
      final id = await _db.insertParsedTransaction(transaction);
      if (id > 0) {
        SmsLogger.db('Transaction saved successfully id=$id');
        return true;
      }
      SmsLogger.db('Insert returned id=$id — not saved');
      return false;
    } catch (error, stackTrace) {
      SmsLogger.db('Error saving transaction: $error');
      SmsLogger.db('$stackTrace');
      rethrow;
    }
  }
}
