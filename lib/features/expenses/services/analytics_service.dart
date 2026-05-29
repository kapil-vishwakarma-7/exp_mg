import 'package:intl/intl.dart';

import '../models/expense.dart';

/// Precomputed analytics for a month. Avoids repeated service calls in build.
class AnalyticsSnapshot {
  AnalyticsSnapshot._({
    required this.month,
    required this.monthlySpending,
    required this.categoryBreakdown,
    required this.dailySpending,
    required this.topCategory,
    required this.highestSpendingDay,
    required this.monthExpenses,
  });

  final DateTime month;
  final double monthlySpending;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> dailySpending;
  final String? topCategory;
  final DateTime? highestSpendingDay;
  final List<Expense> monthExpenses;

  bool get isEmpty => monthExpenses.isEmpty;

  factory AnalyticsSnapshot.compute(
    List<Expense> expenses,
    DateTime month,
    AnalyticsService service,
  ) {
    final monthExpenses = service.filterByMonth(expenses, month);

    return AnalyticsSnapshot._(
      month: month,
      monthlySpending: service.getMonthlySpending(expenses, month: month),
      categoryBreakdown: service.getCategoryBreakdown(monthExpenses),
      dailySpending: service.getDailySpending(monthExpenses),
      topCategory: service.getTopCategory(monthExpenses),
      highestSpendingDay: service.getHighestSpendingDay(monthExpenses),
      monthExpenses: monthExpenses,
    );
  }
}

class AnalyticsService {
  List<Expense> filterByMonth(List<Expense> expenses, DateTime month) {
    return expenses
        .where(
          (expense) =>
              expense.date.year == month.year &&
              expense.date.month == month.month,
        )
        .toList();
  }

  double getTotalSpending(List<Expense> expenses) {
    return expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
  }

  double getMonthlySpending(
    List<Expense> expenses, {
    DateTime? month,
  }) {
    final target = month ?? DateTime.now();
    final monthly = filterByMonth(expenses, target);
    return getTotalSpending(monthly);
  }

  Map<String, double> getCategoryBreakdown(List<Expense> expenses) {
    final breakdown = <String, double>{};
    for (final expense in expenses) {
      breakdown.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return breakdown;
  }

  Map<String, double> getDailySpending(List<Expense> expenses) {
    final daily = <String, double>{};
    for (final expense in expenses) {
      final key = _dateKey(expense.date);
      daily.update(
        key,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return daily;
  }

  String? getTopCategory(List<Expense> expenses) {
    final breakdown = getCategoryBreakdown(expenses);
    if (breakdown.isEmpty) return null;

    return breakdown.entries
        .reduce(
          (best, entry) => entry.value > best.value ? entry : best,
        )
        .key;
  }

  DateTime? getHighestSpendingDay(List<Expense> expenses) {
    final daily = getDailySpending(expenses);
    if (daily.isEmpty) return null;

    final topEntry = daily.entries.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    );
    return DateTime.parse(topEntry.key);
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(amount);
  }

  String formatMonthLabel(DateTime month) {
    return DateFormat('MMMM yyyy').format(month);
  }

  String formatDayLabel(DateTime date) {
    return DateFormat('EEEE, dd MMM yyyy').format(date);
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(
      DateTime(date.year, date.month, date.day),
    );
  }
}
