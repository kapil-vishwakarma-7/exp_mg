import 'package:intl/intl.dart';

import '../../utils/recurring_date_utils.dart';

/// Formats due date as "Due today", "Due tomorrow", or "Due in X days".
String formatDueDate(DateTime dueDate) {
  final today = dateOnly(DateTime.now());
  final due = dateOnly(dueDate);
  final days = due.difference(today).inDays;

  if (days <= 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due in $days days';
}

/// True when payment is due within 2 days (including today).
bool isUrgentPayment(DateTime dueDate) {
  final days =
      dateOnly(dueDate).difference(dateOnly(DateTime.now())).inDays;
  return days <= 2;
}

String formatFrequencyLabel(String frequency, int interval) {
  final base = frequency[0].toUpperCase() + frequency.substring(1).toLowerCase();
  if (interval <= 1) return base;
  return 'Every $interval ${base.toLowerCase()}';
}

String formatExactDueDate(DateTime dueDate) {
  return DateFormat('dd MMM yyyy').format(dueDate);
}
