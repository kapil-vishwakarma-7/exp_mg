import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _databaseName = 'expenses.db';
  static const int _databaseVersion = 1;
  static const String tableExpenses = 'expenses';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    debugPrint('[DB] Initializing database at $path');

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        debugPrint('[DB] Creating expenses table');
        await db.execute('''
          CREATE TABLE $tableExpenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    final data = expense.toMap()..remove('id');
    final id = await db.insert(tableExpenses, data);
    debugPrint('[DB] insertExpense id=$id amount=${expense.amount}');
    return id;
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      orderBy: 'date DESC, id DESC',
    );
    debugPrint('[DB] getAllExpenses count=${rows.length}');
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    final deleted = await db.delete(
      tableExpenses,
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    debugPrint('[DB] deleteExpense id=$id deleted=$deleted');
    return deleted;
  }

  Future<int> updateExpense(Expense expense) async {
    if (expense.id == null) {
      throw ArgumentError('Expense id is required for update');
    }
    final db = await database;
    final updated = await db.update(
      tableExpenses,
      expense.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: <Object>[expense.id!],
    );
    debugPrint('[DB] updateExpense id=${expense.id} updated=$updated');
    return updated;
  }
}
