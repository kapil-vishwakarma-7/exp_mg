import '../../expenses/database/database_helper.dart';
import '../../expenses/services/confirmation_service.dart';
import '../../expenses/services/merchant_icon_service.dart';
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
    MerchantIconService? merchantIconService,
  })  : _db = databaseHelper ?? DatabaseHelper.instance,
        _deduplicator = deduplicator ??
            SmsDeduplicator(databaseHelper: databaseHelper),
        _subscriptionService = subscriptionService ?? SubscriptionService(),
        _confirmationService = confirmationService ?? ConfirmationService(),
        _merchantIconService = merchantIconService ?? MerchantIconService();

  final DatabaseHelper _db;
  final SmsDeduplicator _deduplicator;
  final SubscriptionService _subscriptionService;
  final ConfirmationService _confirmationService;
  final MerchantIconService _merchantIconService;

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

      // Merchant icon — ensure record exists and queue icon download
      // (fire-and-forget, never blocks the save path).
      unawaited(
        _merchantIconService
            .processMerchant(
          merchantName: transaction.merchant,
          category: transaction.category,
        )
            .catchError((Object e) {
          SmsLogger.db('[ICON] processMerchant error: $e');
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
  /// Also re-triggers merchant icon processing in case the AI returned
  /// a better merchant name.
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

      // Re-process icon if merchant name improved.
      if (enriched.merchant != original.merchant &&
          enriched.merchant != 'Unknown') {
        unawaited(
          _merchantIconService
              .processMerchant(
            merchantName: enriched.merchant,
            category: enriched.category,
          )
              .catchError((Object e) {
            SmsLogger.db('[ICON] enrich processMerchant error: $e');
          }),
        );
      }
    } catch (e) {
      SmsLogger.db('[ENRICH] Failed (ignored): $e');
    }
  }
}

// Avoids the `unawaited_futures` lint without importing async package.
void unawaited(Future<void> future) {}
