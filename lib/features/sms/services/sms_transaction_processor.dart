import '../../expenses/database/database_helper.dart';
import '../../expenses/services/confirmation_service.dart';
import '../models/parsed_transaction.dart';
import '../utils/sms_logger.dart';
import 'sms_deduplicator.dart';
import 'subscription_service.dart';

class SmsTransactionProcessor {
  SmsTransactionProcessor({
    DatabaseHelper? databaseHelper,
    SmsDeduplicator? deduplicator,
    SubscriptionService? subscriptionService,
    ConfirmationService? confirmationService,
  })  : _db = databaseHelper ?? DatabaseHelper.instance,
        _deduplicator = deduplicator ??
            SmsDeduplicator(databaseHelper: databaseHelper),
        _subscriptionService = subscriptionService ?? SubscriptionService(),
        _confirmationService =
            confirmationService ?? ConfirmationService();

  final DatabaseHelper _db;
  final SmsDeduplicator _deduplicator;
  final SubscriptionService _subscriptionService;
  final ConfirmationService _confirmationService;

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

      SmsLogger.db('Transaction saved id=$id');

      // Auto-confirm if merchant is already trusted (fire-and-forget).
      unawaited(
        _confirmationService
            .autoConfirmIfTrusted(id, transaction.merchant)
            .catchError((Object e) {
          SmsLogger.db('[CONFIRM] autoConfirm error: $e');
        }),
      );

      // Subscription detection (fire-and-forget).
      unawaited(
        _subscriptionService
            .detectAndLink(transaction, savedExpenseId: id)
            .then((sub) {
          if (sub != null) {
            SmsLogger.db(
              '[SUB] Linked expense id=$id → sub id=${sub.id} '
              '(${sub.merchant})',
            );
          }
        }).catchError((Object e) {
          SmsLogger.db('[SUB] detectAndLink error: $e');
        }),
      );

      return true;
    } catch (error, stackTrace) {
      SmsLogger.db('Error saving transaction: $error');
      SmsLogger.db('$stackTrace');
      rethrow;
    }
  }

  /// Updates an already-saved transaction with AI-enriched fields.
  ///
  /// Finds the existing record by [original]'s dedupeKey and overwrites
  /// merchant, category, confidenceScore, and confirmationStatus with the
  /// values from [enriched]. Amount, type, and date are never changed.
  Future<void> enrichTransaction(
    ParsedTransaction original,
    ParsedTransaction enriched,
  ) async {
    try {
      await _db.enrichParsedTransaction(
        dedupeKey: original.dedupeKey,
        merchant: enriched.merchant,
        category: enriched.category,
        confidenceScore: enriched.confidenceScore,
        confirmationStatus: enriched.confirmationStatus,
      );
      SmsLogger.db(
        '[ENRICH] Updated merchant=${enriched.merchant} '
        'category=${enriched.category}',
      );
    } catch (e) {
      SmsLogger.db('[ENRICH] Failed (ignored): $e');
    }
  }
}

// Avoids the `unawaited_futures` lint without importing async package.
void unawaited(Future<void> future) {}
