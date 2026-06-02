import '../../expenses/database/database_helper.dart';
import '../models/parsed_transaction.dart';
import '../utils/sms_logger.dart';
import 'sms_deduplicator.dart';
import 'subscription_service.dart';

class SmsTransactionProcessor {
  SmsTransactionProcessor({
    DatabaseHelper? databaseHelper,
    SmsDeduplicator? deduplicator,
    SubscriptionService? subscriptionService,
  })  : _db = databaseHelper ?? DatabaseHelper.instance,
        _deduplicator = deduplicator ??
            SmsDeduplicator(databaseHelper: databaseHelper),
        _subscriptionService =
            subscriptionService ?? SubscriptionService();

  final DatabaseHelper _db;
  final SmsDeduplicator _deduplicator;
  final SubscriptionService _subscriptionService;

  Future<bool> saveIfNew(ParsedTransaction transaction) async {
    SmsLogger.db('Checking duplicate before save…');
    if (await _deduplicator.isDuplicate(transaction)) {
      return false;
    }

    SmsLogger.db('Saving transaction: ${transaction.toLogMap()}');
    try {
      final id = await _db.insertParsedTransaction(transaction);
      if (id <= 0) {
        SmsLogger.db('Insert returned id=$id — not saved');
        return false;
      }

      SmsLogger.db('Transaction saved successfully id=$id');

      // Step 8 — run subscription detection in the background.
      // Fire-and-forget: never block or fail the main save path.
      unawaited(
        _subscriptionService.detectAndLink(
          transaction,
          savedExpenseId: id,
        ).then((sub) {
          if (sub != null) {
            SmsLogger.db(
              '[SUB] Linked expense id=$id → subscription id=${sub.id} '
              '(${sub.merchant}, confidence=${sub.confidenceScore})',
            );
          }
        }).catchError((Object e) {
          SmsLogger.db('[SUB] detectAndLink failed silently: $e');
        }),
      );

      return true;
    } catch (error, stackTrace) {
      SmsLogger.db('Error saving transaction: $error');
      SmsLogger.db('$stackTrace');
      rethrow;
    }
  }
}

// Avoids the `unawaited_futures` lint without importing async package.
void unawaited(Future<void> future) {}
