import '../domain/models/expense.dart';
import 'expense_database.dart';

class ExpenseRepository {
  ExpenseRepository(this._databaseProvider);

  final ExpenseDatabase _databaseProvider;

  Future<List<Expense>> getExpenses() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      ExpenseDatabase.tableExpenses,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<void> addExpense(Expense expense) async {
    final db = await _databaseProvider.database;
    await db.insert(ExpenseDatabase.tableExpenses, expense.toMap());
  }
}
