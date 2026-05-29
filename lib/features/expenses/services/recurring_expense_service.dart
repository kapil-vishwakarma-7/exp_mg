import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';
import '../utils/recurring_date_utils.dart';

class RecurringExpenseService {
  RecurringExpenseService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<int> insertRecurringExpense(RecurringExpense recurring) async {
    debugPrint('[Recurring] insertRecurringExpense ${recurring.title}');
    final id = await _db.insertRecurringExpense(recurring);
    if (id <= 0) {
      throw StateError('insertRecurringExpense failed: invalid id $id');
    }
    return id;
  }

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final list = await _db.getRecurringExpenses();
    debugPrint('[Recurring] getRecurringExpenses count=${list.length}');
    return list;
  }

  Future<int> updateNextDueDate(int id, DateTime nextDueDate) async {
    return _db.updateNextDueDate(id, dateOnly(nextDueDate));
  }

  Future<List<RecurringExpense>> getUpcomingPayments({int daysAhead = 7}) async {
    final items = await _db.getUpcomingPayments(daysAhead: daysAhead);
    final today = dateOnly(DateTime.now());

    final filtered = items.where((item) {
      if (item.endDate != null && today.isAfter(dateOnly(item.endDate!))) {
        return false;
      }
      return true;
    }).toList();

    debugPrint('Upcoming payments count: ${filtered.length}');
    for (final item in filtered) {
      debugPrint('${item.title} → ${item.nextDueDate}');
    }

    return filtered;
  }

  /// Generates due expenses and advances [next_due_date] for each recurring row.
  Future<int> processRecurringExpenses() async {
    debugPrint('[Recurring] Processing recurring expenses...');
    final today = dateOnly(DateTime.now());
    final recurringList = await getRecurringExpenses();
    var createdCount = 0;

    debugPrint(
      '[Recurring] processRecurringExpenses today=$today rows=${recurringList.length}',
    );

    for (final item in recurringList) {
      if (item.id == null) {
        debugPrint('[Recurring] skip row without id: ${item.title}');
        continue;
      }

      debugPrint(
        '[Recurring] Checking: ${item.title}, next_due_date: ${dateOnly(item.nextDueDate)}, auto_add=${item.autoAdd}',
      );

      if (!item.autoAdd) {
        debugPrint('[Recurring] skip auto_add=false id=${item.id}');
        continue;
      }

      final endDate =
          item.endDate != null ? dateOnly(item.endDate!) : null;

      if (endDate != null && today.isAfter(endDate)) {
        debugPrint('[Recurring] skip id=${item.id} past end_date=$endDate');
        continue;
      }

      final originalNextDue = dateOnly(item.nextDueDate);
      var nextDue = originalNextDue;
      var cycles = 0;

      while (isOnOrAfterDueDate(today, nextDue)) {
        if (endDate != null && nextDue.isAfter(endDate)) {
          debugPrint('[Recurring] stop id=${item.id} nextDue past end_date');
          break;
        }

        final expense = Expense(
          title: item.title,
          amount: item.amount,
          category: item.category,
          date: nextDue,
          note: 'Recurring: ${item.title}',
          createdAt: DateTime.now(),
        );

        await _db.insertExpense(expense);
        createdCount++;
        cycles++;
        debugPrint(
          '[Recurring] inserted expense id=${item.id} cycle=$cycles date=$nextDue',
        );

        nextDue = dateOnly(
          getNextDate(nextDue, item.frequency, item.interval),
        );
      }

      if (compareDate(nextDue, originalNextDue) != 0) {
        await updateNextDueDate(item.id!, nextDue);
        debugPrint(
          '[Recurring] updated next_due id=${item.id} $originalNextDue -> $nextDue',
        );
      }
    }

    debugPrint(
      '[Recurring] processRecurringExpenses done created=$createdCount',
    );
    return createdCount;
  }
}
