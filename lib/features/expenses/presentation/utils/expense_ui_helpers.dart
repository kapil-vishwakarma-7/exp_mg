import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';

IconData categoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant_outlined;
    case 'Travel':
      return Icons.directions_car_outlined;
    case 'Bills':
      return Icons.receipt_long_outlined;
    case 'Shopping':
      return Icons.shopping_bag_outlined;
    default:
      return Icons.category_outlined;
  }
}

String formatExpenseAmount(double amount) {
  return NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(amount);
}

String formatExpenseDateTime(DateTime date) {
  return DateFormat('dd MMM, hh:mm a').format(date);
}

String dateGroupLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expenseDay = DateTime(date.year, date.month, date.day);

  if (expenseDay == today) return 'Today';
  if (expenseDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return 'Older';
}

String expenseDisplayTitle(Expense expense) {
  if (expense.note.isNotEmpty) return expense.note;
  return expense.category;
}
