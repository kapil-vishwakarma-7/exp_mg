import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../services/expense_service.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({ExpenseService? service})
      : _service = service ?? ExpenseService();

  final ExpenseService _service;
  final List<Expense> _expenses = <Expense>[];

  bool _isLoading = false;

  List<Expense> get expenses => List<Expense>.unmodifiable(_expenses);
  bool get isLoading => _isLoading;
  double get totalAmount =>
      _expenses.fold(0, (total, expense) => total + expense.amount);

  Future<void> fetchExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final items = await _service.getAllExpenses();
      _expenses
        ..clear()
        ..addAll(items);
      debugPrint('[Provider] fetchExpenses count=${_expenses.length}');
    } catch (error, stackTrace) {
      debugPrint('[Provider] fetchExpenses failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense(Expense expense) async {
    try {
      await _service.insertExpense(expense);
      debugPrint('[Provider] addExpense success id pending refresh');
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
