import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';

class ExpenseService {
  ExpenseService({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> insertExpense(Expense expense) async {
    debugPrint('[Service] insertExpense category=${expense.category}');
    return _databaseHelper.insertExpense(expense);
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
}
