import 'package:flutter/foundation.dart';

import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({required this.repository});

  final ExpenseRepository repository;
  final List<Expense> _expenses = <Expense>[];

  bool _isLoading = false;

  List<Expense> get expenses => List<Expense>.unmodifiable(_expenses);
  bool get isLoading => _isLoading;
  double get totalAmount =>
      _expenses.fold(0, (total, expense) => total + expense.amount);

  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    final items = await repository.getExpenses();
    _expenses
      ..clear()
      ..addAll(items);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense({
    required double amount,
    required String category,
    required String note,
    required DateTime date,
  }) async {
    final expense = Expense(
      amount: amount,
      category: category.trim(),
      note: note.trim(),
      date: date,
    );

    await repository.addExpense(expense);
    await loadExpenses();
  }
}
