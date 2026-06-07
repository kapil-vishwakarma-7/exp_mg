import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/recurring_data.dart';
import '../models/recurring_expense.dart';
import '../services/expense_service.dart';
import '../../sms/models/detected_subscription.dart';
import '../../sms/models/parsed_transaction.dart';
import '../../sms/services/subscription_service.dart';
import '../presentation/widgets/subscription_details_sheet.dart'
    show SubscriptionDetails;

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({ExpenseService? service})
      : _service = service ?? ExpenseService();

  final ExpenseService _service;

  // ── In-memory state ───────────────────────────────────────────────────────

  // All non-ignored expenses (confirmed + pending).
  final List<Expense> _expenses = <Expense>[];
  // Only pending — drives the "Needs Review" banner.
  final List<Expense> _pendingExpenses = <Expense>[];

  List<RecurringExpense> _upcomingPayments = <RecurringExpense>[];
  List<DetectedSubscription> _subscriptions = <DetectedSubscription>[];

  bool _isLoading = false;
  bool _initialized = false;
  int _refreshVersion = 0;

  // ── Public getters ────────────────────────────────────────────────────────

  /// All non-ignored (confirmed + pending), for the transaction list.
  List<Expense> get expenses => List<Expense>.unmodifiable(_expenses);

  /// Only confirmed — shown on home / used in analytics totals.
  List<Expense> get confirmedExpenses =>
      List<Expense>.unmodifiable(_expenses.where((e) => e.isConfirmed).toList());

  /// Only pending — drives the "Needs Review" banner.
  List<Expense> get pendingExpenses =>
      List<Expense>.unmodifiable(_pendingExpenses);

  List<RecurringExpense> get upcomingPayments =>
      List<RecurringExpense>.unmodifiable(_upcomingPayments);
  List<DetectedSubscription> get subscriptions =>
      List<DetectedSubscription>.unmodifiable(_subscriptions);

  bool get isLoading => _isLoading;
  int get refreshVersion => _refreshVersion;
  int get pendingCount => _pendingExpenses.length;

  /// Total debit spend — confirmed transactions only (excludes pending).
  double get totalAmount => _expenses
      .where((e) => e.isDebit && e.isConfirmed)
      .fold(0.0, (sum, e) => sum + e.amount);

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await fetchExpenses();
    await _service.logRecurringDebugDashboard();
  }

  // ── Data fetch ────────────────────────────────────────────────────────────

  Future<void> fetchExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.processRecurringExpenses();

      // Visible list (confirmed + pending, no ignored).
      final items = await _service.getAllExpenses();
      _expenses
        ..clear()
        ..addAll(items);

      // Pending-only list for review banner.
      final pending = await _service.getPendingExpenses();
      _pendingExpenses
        ..clear()
        ..addAll(pending);

      await _fetchUpcomingPayments();
      await _fetchSubscriptions();

      _refreshVersion++;
      debugPrint(
        '[Provider] fetchExpenses total=${_expenses.length} '
        'pending=${_pendingExpenses.length}',
      );
    } catch (error, stackTrace) {
      debugPrint('[Provider] fetchExpenses failed: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Confirmation actions ──────────────────────────────────────────────────

  /// Confirms a pending expense and learns the merchant as trusted.
  Future<void> confirmExpense(Expense expense) async {
    try {
      await _service.confirmExpense(expense);
      // Move from pending → confirmed in-memory immediately.
      _pendingExpenses.removeWhere((e) => e.id == expense.id);
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        _expenses[idx] = expense.copyWith(
          confirmationStatus: ConfirmationStatus.confirmed,
        );
      }
      _refreshVersion++;
      notifyListeners();
      debugPrint('[Provider] confirmExpense id=${expense.id}');
    } catch (e, st) {
      debugPrint('[Provider] confirmExpense error: $e\n$st');
    }
  }

  /// Confirms a pending subscription expense AND upserts the subscription
  /// record with user-provided details from [SubscriptionDetailsSheet].
  Future<void> confirmSubscription(
    Expense expense,
    SubscriptionDetails details,
  ) async {
    try {
      // 1. Confirm the expense in the DB and mark merchant trusted.
      await _service.confirmExpense(expense);

      // 2. Upsert the subscription record with user-confirmed details.
      final subscriptionService = SubscriptionService();

      // Build a minimal ParsedTransaction so SubscriptionService can upsert.
      final syntheticTx = ParsedTransaction(
        amount: expense.amount,
        type: 'debit',
        merchant: expense.merchant ?? details.displayName,
        category: expense.category,
        transactionTime: expense.transactionTime,
        rawSms: expense.rawSms ?? '',
        isSubscription: true,
        confidenceScore: 'high', // user confirmed = high confidence
        confirmationStatus: ConfirmationStatus.confirmed,
      );

      await subscriptionService.detectAndLink(
        syntheticTx,
        savedExpenseId: expense.id!,
      );

      // 3. Update in-memory state.
      _pendingExpenses.removeWhere((e) => e.id == expense.id);
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        _expenses[idx] = expense.copyWith(
          confirmationStatus: ConfirmationStatus.confirmed,
        );
      }

      // Refresh subscriptions list so the subscriptions screen updates.
      await _fetchSubscriptions();

      _refreshVersion++;
      notifyListeners();
      debugPrint(
        '[Provider] confirmSubscription id=${expense.id} '
        'name=${details.displayName} freq=${details.frequency}',
      );
    } catch (e, st) {
      debugPrint('[Provider] confirmSubscription error: $e\n$st');
    }
  }

  /// Ignores a pending expense — removes it from all lists.
  Future<void> ignoreExpense(Expense expense) async {
    try {
      await _service.ignoreExpense(expense);
      _pendingExpenses.removeWhere((e) => e.id == expense.id);
      _expenses.removeWhere((e) => e.id == expense.id);
      _refreshVersion++;
      notifyListeners();
      debugPrint('[Provider] ignoreExpense id=${expense.id}');
    } catch (e, st) {
      debugPrint('[Provider] ignoreExpense error: $e\n$st');
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<bool> addExpense({
    required Expense expense,
    RecurringData? recurring,
  }) async {
    try {
      final saved = await _service.addExpenseEntry(
        expense: expense,
        recurring: recurring,
      );
      if (!saved) return false;
      await fetchExpenses();
      return true;
    } catch (e, st) {
      debugPrint('[Provider] addExpense failed: $e\n$st');
      return false;
    }
  }

  Future<bool> updateExpense(Expense expense) async {
    try {
      // Auto-confirm when user manually edits.
      final toSave = expense.isConfirmed
          ? expense
          : expense.copyWith(
              confirmationStatus: ConfirmationStatus.confirmed,
            );
      await _service.updateExpense(toSave);
      final idx = _expenses.indexWhere((e) => e.id == toSave.id);
      if (idx != -1) {
        _expenses[idx] = toSave;
        _pendingExpenses.removeWhere((e) => e.id == toSave.id);
        _refreshVersion++;
        notifyListeners();
      } else {
        await fetchExpenses();
      }
      debugPrint('[Provider] updateExpense id=${toSave.id}');
      return true;
    } catch (e, st) {
      debugPrint('[Provider] updateExpense failed: $e\n$st');
      return false;
    }
  }

  /// Updates both the expense AND the linked subscription record together.
  Future<bool> updateExpenseWithSubscription(
    Expense expense,
    DetectedSubscription subscription,
  ) async {
    try {
      final toSave = expense.isConfirmed
          ? expense
          : expense.copyWith(confirmationStatus: ConfirmationStatus.confirmed);
      await _service.updateExpense(toSave);
      await _service.updateSubscription(subscription);

      final idx = _expenses.indexWhere((e) => e.id == toSave.id);
      if (idx != -1) {
        _expenses[idx] = toSave;
        _pendingExpenses.removeWhere((e) => e.id == toSave.id);
      }

      // Refresh the subscriptions list so the subscriptions screen is current.
      await _fetchSubscriptions();

      _refreshVersion++;
      notifyListeners();
      debugPrint(
        '[Provider] updateExpenseWithSubscription id=${toSave.id} '
        'subId=${subscription.id}',
      );
      return true;
    } catch (e, st) {
      debugPrint('[Provider] updateExpenseWithSubscription failed: $e\n$st');
      return false;
    }
  }

  Future<void> restoreExpense(Expense expense) async {
    try {
      await _service.insertExpense(expense.copyWith(id: null));
      await fetchExpenses();
    } catch (e, st) {
      debugPrint('[Provider] restoreExpense failed: $e\n$st');
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      await _service.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      _pendingExpenses.removeWhere((e) => e.id == id);
      _refreshVersion++;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[Provider] deleteExpense failed: $e\n$st');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<RecurringExpense>> loadUpcomingPayments({
    int daysAhead = 7,
  }) =>
      _service.getUpcomingPayments(daysAhead: daysAhead);

  Future<List<DetectedSubscription>> loadUpcomingSubscriptions({
    int daysAhead = 7,
  }) =>
      _service.getUpcomingSubscriptions(daysAhead: daysAhead);

  Future<void> _fetchUpcomingPayments({int daysAhead = 7}) async {
    _upcomingPayments =
        await _service.getUpcomingPayments(daysAhead: daysAhead);
    debugPrint(
        '[Provider] upcomingPayments count=${_upcomingPayments.length}');
  }

  Future<void> _fetchSubscriptions() async {
    _subscriptions = await _service.getAllSubscriptions();
    debugPrint('[Provider] subscriptions count=${_subscriptions.length}');
  }
}
