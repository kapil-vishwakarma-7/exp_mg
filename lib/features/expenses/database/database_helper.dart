import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';
import '../models/recurring_expense.dart';
import '../../sms/models/parsed_transaction.dart';
import '../../sms/utils/sms_expense_mapper.dart';
import '../services/recurring_debug.dart';
import '../utils/recurring_date_utils.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _databaseName = 'expenses.db';
  static const int _databaseVersion = 6;
  static const String tableExpenses = 'expenses';
  static const String tableRecurringExpenses = 'recurring_expenses';

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
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB] onCreate v$version');
    await _createExpensesTable(db);
    await _createRecurringExpensesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] onUpgrade $oldVersion -> $newVersion');

    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info($tableExpenses)');
      final names = columns.map((row) => row['name'] as String).toSet();

      if (!names.contains('title')) {
        await db.execute('ALTER TABLE $tableExpenses RENAME TO expenses_old');
        await _createExpensesTable(db);
        await db.execute('''
          INSERT INTO $tableExpenses (id, title, amount, category, date, note, created_at)
          SELECT id,
                 CASE WHEN note IS NULL OR note = '' THEN category ELSE note END,
                 amount, category, date,
                 COALESCE(note, ''),
                 date
          FROM expenses_old
        ''');
        await db.execute('DROP TABLE expenses_old');
      }

      await _createRecurringExpensesTable(db);
    }

    if (oldVersion < 4) {
      await _normalizeRecurringExpensesTable(db);
    }

    if (oldVersion < 5) {
      await _migrateExpensesSmsColumns(db);
    }

    if (oldVersion < 6) {
      await _migrateExpensesTransactionTime(db);
    }
  }

  Future<void> _migrateExpensesTransactionTime(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableExpenses)');
    final names = columns.map((row) => row['name'] as String).toSet();

    if (!names.contains('transaction_time')) {
      await db.execute(
        'ALTER TABLE $tableExpenses ADD COLUMN transaction_time TEXT',
      );
      await db.execute('''
        UPDATE $tableExpenses
        SET transaction_time = date
        WHERE transaction_time IS NULL
      ''');
    }
  }

  Future<void> _migrateExpensesSmsColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableExpenses)');
    final names = columns.map((row) => row['name'] as String).toSet();

    if (!names.contains('transaction_type')) {
      await db.execute(
        'ALTER TABLE $tableExpenses ADD COLUMN transaction_type TEXT',
      );
    }
    if (!names.contains('merchant')) {
      await db.execute('ALTER TABLE $tableExpenses ADD COLUMN merchant TEXT');
    }
    if (!names.contains('raw_sms')) {
      await db.execute('ALTER TABLE $tableExpenses ADD COLUMN raw_sms TEXT');
    }
    if (!names.contains('sms_hash')) {
      await db.execute('ALTER TABLE $tableExpenses ADD COLUMN sms_hash TEXT');
    }

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_sms_hash
      ON $tableExpenses(sms_hash)
      WHERE sms_hash IS NOT NULL
    ''');
  }

  /// Ensures [repeat_interval] exists and removes legacy [interval] column.
  Future<void> _normalizeRecurringExpensesTable(Database db) async {
    var columns =
        await db.rawQuery('PRAGMA table_info($tableRecurringExpenses)');
    if (columns.isEmpty) {
      await _createRecurringExpensesTable(db);
      return;
    }

    var names = columns.map((row) => row['name'] as String).toSet();

    if (!names.contains('repeat_interval')) {
      debugPrint('[DB] Adding repeat_interval column');
      await db.execute('''
        ALTER TABLE $tableRecurringExpenses
        ADD COLUMN repeat_interval INTEGER NOT NULL DEFAULT 1
      ''');
      if (names.contains('interval')) {
        await db.execute('''
          UPDATE $tableRecurringExpenses
          SET repeat_interval = "interval"
        ''');
      }
      names = names.union({'repeat_interval'});
    }

    if (!names.contains('interval')) return;

    debugPrint('[DB] Rebuilding recurring_expenses (drop legacy interval)');
    await db.execute(
      'ALTER TABLE $tableRecurringExpenses RENAME TO recurring_expenses_legacy',
    );
    await _createRecurringExpensesTable(db);
    await db.execute('''
      INSERT INTO $tableRecurringExpenses (
        id, title, amount, category, frequency, repeat_interval,
        start_date, next_due_date, end_date, auto_add, created_at
      )
      SELECT
        id, title, amount, category, frequency,
        COALESCE(repeat_interval, "interval", 1),
        start_date, next_due_date, end_date, auto_add, created_at
      FROM recurring_expenses_legacy
    ''');
    await db.execute('DROP TABLE recurring_expenses_legacy');
  }

  Future<void> _createExpensesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableExpenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL,
        created_at TEXT NOT NULL,
        transaction_type TEXT,
        merchant TEXT,
        raw_sms TEXT,
        sms_hash TEXT,
        transaction_time TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_sms_hash
      ON $tableExpenses(sms_hash)
      WHERE sms_hash IS NOT NULL
    ''');
  }

  Future<void> _createRecurringExpensesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableRecurringExpenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        frequency TEXT NOT NULL,
        repeat_interval INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        end_date TEXT,
        auto_add INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    final data = expense.toMap()..remove('id');
    final id = await db.insert(tableExpenses, data);
    debugPrint('[DB] insertExpense id=$id title=${expense.title}');
    return id;
  }

  Future<bool> smsHashExists(String hash) async {
    if (hash.isEmpty) return false;
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      columns: <String>['id'],
      where: 'sms_hash = ?',
      whereArgs: <Object>[hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> insertParsedTransaction(ParsedTransaction transaction) async {
    final expense = parsedTransactionToExpense(transaction);
    final db = await database;
    final data = expense.toMap()..remove('id');

    try {
      debugPrint('[DB] insertParsedTransaction start ${transaction.merchant}');
      final id = await db.insert(tableExpenses, data);
      debugPrint(
        '[DB] insertParsedTransaction success id=$id ${transaction.merchant}',
      );
      return id;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        debugPrint('[DB] insertParsedTransaction duplicate hash');
        return 0;
      }
      debugPrint('[DB] insertParsedTransaction error: $error');
      rethrow;
    }
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      orderBy: 'COALESCE(transaction_time, date) DESC, id DESC',
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

  Future<int> insertRecurringExpense(RecurringExpense recurring) async {
    final db = await database;
    final data = recurring.toDbMap();
    logRecurringInsert(recurring);

    final columns =
        await db.rawQuery('PRAGMA table_info($tableRecurringExpenses)');
    final columnNames =
        columns.map((row) => row['name'] as String).toSet();
    if (columnNames.contains('interval') && !data.containsKey('interval')) {
      data['interval'] = recurring.interval;
    }

    final id = await db.insert(tableRecurringExpenses, data);
    debugPrint('[DB] insertRecurringExpense id=$id saved=$data');
    return id;
  }

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await database;
    final rows = await db.query(
      tableRecurringExpenses,
      orderBy: 'next_due_date ASC',
    );
    debugPrint('[DB] Fetched recurring count: ${rows.length}');

    final list = <RecurringExpense>[];
    for (final row in rows) {
      try {
        list.add(RecurringExpense.fromMap(row));
      } catch (error, stackTrace) {
        debugPrint('[DB] Failed to map recurring row=$row error=$error');
        debugPrint('$stackTrace');
      }
    }
    return list;
  }

  Future<List<RecurringExpense>> getUpcomingPayments({int daysAhead = 7}) async {
    final now = DateTime.now();
    final today = dateOnly(now);
    final futureDate = today.add(Duration(days: daysAhead));
    final todayIso = toIsoDateString(today);
    final futureIso = toIsoDateString(futureDate);
    final db = await database;

    final rows = await db.query(
      tableRecurringExpenses,
      where:
          'next_due_date IS NOT NULL AND next_due_date != ? AND '
          'date(next_due_date) >= date(?) AND date(next_due_date) <= date(?)',
      whereArgs: <String>['', todayIso, futureIso],
      orderBy: 'next_due_date ASC',
    );

    debugPrint(
      '[DB] getUpcomingPayments today=$todayIso future=$futureIso raw=${rows.length}',
    );

    final list = <RecurringExpense>[];
    for (final row in rows) {
      try {
        list.add(RecurringExpense.fromMap(row));
      } catch (error, stackTrace) {
        debugPrint('[DB] skip invalid upcoming row=$row error=$error');
        debugPrint('$stackTrace');
      }
    }
    return list;
  }

  Future<int> updateNextDueDate(int id, DateTime nextDueDate) async {
    final db = await database;
    final value = formatDbDate(nextDueDate);
    final updated = await db.update(
      tableRecurringExpenses,
      <String, Object?>{'next_due_date': value},
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    debugPrint('[DB] updateNextDueDate id=$id next=$value updated=$updated');
    return updated;
  }

  Future<void> logDebugDashboard() => logRecurringDebugDashboard(this);
}
