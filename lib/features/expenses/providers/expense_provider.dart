import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/recurring_data.dart';
import '../models/recurring_expense.dart';
import '../services/expense_service.dart';
import '../../sms/models/detected_subscription.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({ExpenseService? service})
      : _service = service ?? ExpenseService();

  final ExpenseService _service;
  final List<Expense> _expenses = <Expense>[];
  List<RecurringExpense> _upcomingPayments = <RecurringExpense>[];
  List<DetectedSubscription> _subscriptions = <DetectedSubscription>[];

  bool _isLoading = false;
  bool _initialized = false;
  int _refreshVersion = 0;

  List<Expense> get expenses => List<Expense>.unmodifiable(_expenses);
  List<RecurringExpense> get upcomingPayments =>
      List<RecurringExpense>.unmodifiable(_upcomingPayments);
  List<DetectedSubscription> get subscriptions =>
      List<DetectedSubscription>.unmodifiable(_subscriptions);
  bool get isLoading => _isLoading;
  int get refreshVersion => _refreshVersion;
  double get totalAmount => _expenses
      .where((expense) => expense.isDebit)
      .fold(0, (total, expense) => total + expense.amount);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await fetchExpenses();
    await _service.logRecurringDebugDashboard();
  }

  Future<void> fetchExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final generated = await _service.processRecurringExpenses();
      debugPrint('[Provider] processRecurringExpenses generated=$generated');

      final items = await _service.getAllExpenses();
      _expenses
        ..clear()
        ..addAll(items);

      await _fetchUpcomingPayments();
      await _fetchSubscriptions();

      _refreshVersion++;
      debugPrint('[Provider] fetchExpenses count=${_expenses.length}');
    } catch (error, stackTrace) {
      debugPrint('[Provider] fetchExpenses failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<RecurringExpense>> loadUpcomingPayments({
    int daysAhead = 7,
  }) async {
    return _service.getUpcomingPayments(daysAhead: daysAhead);
  }

  Future<void> _fetchUpcomingPayments({int daysAhead = 7}) async {
    _upcomingPayments =
        await _service.getUpcomingPayments(daysAhead: daysAhead);
    debugPrint(
      '[Provider] upcomingPayments count=${_upcomingPayments.length}',
    );
  }

  Future<void> _fetchSubscriptions() async {
    _subscriptions = await _service.getAllSubscriptions();
    debugPrint('[Provider] subscriptions count=${_subscriptions.length}');
  }

  Future<List<DetectedSubscription>> loadUpcomingSubscriptions({
    int daysAhead = 7,
  }) {
    return _service.getUpcomingSubscriptions(daysAhead: daysAhead);
  }

  Future<bool> addExpense({
    required Expense expense,
    RecurringData? recurring,
  }) async {
    try {
      final saved = await _service.addExpenseEntry(
        expense: expense,
        recurring: recurring,
      );
      if (!saved) {
        debugPrint('[Provider] addExpense failed: insert returned false');
        return false;
      }

      debugPrint('[Provider] addExpense success');
      await fetchExpenses();
      return true;
    } catch (error, stackTrace) {
      debugPrint('[Provider] addExpense failed: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      await _service.deleteExpense(id);
      debugPrint('[Provider] deleteExpense id=$id');
      await fetchExpenses();
    } catch (error, stackTrace) {
      debugPrint('[Provider] deleteExpense failed: $error');
      debugPrint('$stackTrace');
    }
  }
}
