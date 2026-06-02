import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/recurring_data.dart';
import '../models/recurring_expense.dart';
import '../services/recurring_debug.dart';
import '../utils/recurring_date_utils.dart';
import '../../sms/models/detected_subscription.dart';
import 'recurring_expense_service.dart';

class ExpenseService {
  ExpenseService({
    DatabaseHelper? databaseHelper,
    RecurringExpenseService? recurringService,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _recurringService = recurringService ??
            RecurringExpenseService(
              databaseHelper: databaseHelper ?? DatabaseHelper.instance,
            );

  final DatabaseHelper _databaseHelper;
  final RecurringExpenseService _recurringService;

  Future<void> logRecurringDebugDashboard() {
    return _databaseHelper.logDebugDashboard();
  }

  Future<int> processRecurringExpenses() {
    return _recurringService.processRecurringExpenses();
  }

  Future<List<RecurringExpense>> getUpcomingPayments({int daysAhead = 7}) {
    return _recurringService.getUpcomingPayments(daysAhead: daysAhead);
  }

  Future<int> insertExpense(Expense expense) async {
    debugPrint('[Service] insertExpense title=${expense.title}');
    return _databaseHelper.insertExpense(expense);
  }

  Future<int> insertRecurringExpense(RecurringExpense recurring) async {
    return _recurringService.insertRecurringExpense(recurring);
  }

  Future<bool> addExpenseEntry({
    required Expense expense,
    RecurringData? recurring,
  }) async {
    if (recurring != null && recurring.isRecurring) {
      final start = dateOnly(recurring.startDate);
      final recurringExpense = RecurringExpense(
        title: expense.title,
        amount: expense.amount,
        category: expense.category,
        frequency: frequencyToDb(recurring.frequency),
        interval: recurring.interval,
        startDate: start,
        nextDueDate: start,
        endDate:
            recurring.endDate != null ? dateOnly(recurring.endDate!) : null,
        autoAdd: recurring.autoAdd,
        createdAt: dateOnly(DateTime.now()),
      );

      logRecurringInsert(recurringExpense);
      final id = await insertRecurringExpense(recurringExpense);
      debugPrint('[Service] saved recurring expense id=$id title=${expense.title}');

      if (recurring.autoAdd) {
        await processRecurringExpenses();
      }
      return id > 0;
    }

    final id = await insertExpense(expense);
    return id > 0;
  }

  Future<List<Expense>> getAllExpenses() async {
    debugPrint('[Service] getAllExpenses');
    return _databaseHelper.getAllExpenses();
  }

  Future<int> deleteExpense(int id) async {
    debugPrint('[Service] deleteExpense id=$id');
    return _databaseHelper.deleteExpense(id);
  }

  Future<int> updateExpense(Expense expense) async {
    debugPrint('[Service] updateExpense id=${expense.id}');
    return _databaseHelper.updateExpense(expense);
  }

  Future<List<DetectedSubscription>> getAllSubscriptions() {
    return _databaseHelper.getAllSubscriptions();
  }

  Future<List<DetectedSubscription>> getUpcomingSubscriptions({
    int daysAhead = 7,
  }) {
    return _databaseHelper.getUpcomingSubscriptions(daysAhead: daysAhead);
  }
}
