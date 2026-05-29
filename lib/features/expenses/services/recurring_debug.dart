import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/recurring_expense.dart';
import '../utils/recurring_date_utils.dart';

/// Temporary debug helper — logs recurring DB state to console.
Future<void> logRecurringDebugDashboard(DatabaseHelper db) async {
  final recurring = await db.getRecurringExpenses();
  final expenses = await db.getAllExpenses();
  final today = dateOnly(DateTime.now());

  debugPrint('════════ RECURRING DEBUG ════════');
  debugPrint('Today (date-only): $today');
  debugPrint('Total recurring entries: ${recurring.length}');
  debugPrint('Total expense entries: ${expenses.length}');

  for (final item in recurring) {
    final due = dateOnly(item.nextDueDate);
    final daysUntil = due.difference(today).inDays;
    debugPrint(
      '• [${item.id}] ${item.title} | ₹${item.amount} | '
      'freq=${item.frequency} every ${item.interval} | '
      'next_due=$due (${daysUntil}d) | auto_add=${item.autoAdd}',
    );
  }

  final recurringGenerated = expenses
      .where((e) => e.note.startsWith('Recurring:'))
      .length;
  debugPrint('Generated recurring expenses (by note): $recurringGenerated');
  debugPrint('══════════════════════════════════');
}

void logRecurringInsert(RecurringExpense expense) {
  debugPrint('[Recurring][INSERT] ${expense.toDbMap()}');
}
