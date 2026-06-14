import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';
import '../models/merchant_preference.dart';
import '../models/recurring_expense.dart';
import '../../sms/models/detected_subscription.dart';
import '../../sms/models/parsed_transaction.dart';
import '../../sms/utils/sms_expense_mapper.dart';
import '../services/recurring_debug.dart';
import '../utils/recurring_date_utils.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _databaseName = 'expenses.db';
  static const int _databaseVersion = 9;
  static const String tableExpenses = 'expenses';
  static const String tableRecurringExpenses = 'recurring_expenses';
  static const String tableUserProfile = 'user_profile';
  static const String tableSubscriptions = 'subscriptions';
  static const String tableMerchantPreferences = 'merchant_preferences';

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
    await _createUserProfileTable(db);
    await _createSubscriptionsTable(db);
    await _createMerchantPreferencesTable(db);
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

    if (oldVersion < 7) {
      await _createUserProfileTable(db);
    }

    if (oldVersion < 8) {
      await _migrateExpensesSubscriptionColumns(db);
      await _createSubscriptionsTable(db);
    }

    if (oldVersion < 9) {
      await _migrateExpensesConfirmationColumns(db);
      await _createMerchantPreferencesTable(db);
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
        transaction_time TEXT,
        is_subscription INTEGER NOT NULL DEFAULT 0,
        subscription_id INTEGER,
        confirmation_status TEXT NOT NULL DEFAULT 'confirmed',
        confidence_score TEXT NOT NULL DEFAULT 'medium'
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_sms_hash
      ON $tableExpenses(sms_hash)
      WHERE sms_hash IS NOT NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_merchant
      ON $tableExpenses(merchant)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_confirmation
      ON $tableExpenses(confirmation_status)
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

  /// Patches an SMS-sourced expense row with AI-enriched fields.
  /// Only merchant, category, confidence_score, and confirmation_status
  /// are updated — amount, type, and date are never changed.
  Future<void> enrichParsedTransaction({
    required String dedupeKey,
    required String merchant,
    required String category,
    required String confidenceScore,
    required String confirmationStatus,
  }) async {
    if (dedupeKey.isEmpty) return;
    final db = await database;
    final updated = await db.update(
      tableExpenses,
      <String, Object?>{
        'merchant': merchant,
        'title': merchant, // keep title in sync
        'category': category,
        'confidence_score': confidenceScore,
        'confirmation_status': confirmationStatus,
      },
      where: 'sms_hash = ?',
      whereArgs: <Object>[dedupeKey],
    );
    debugPrint(
      '[DB] enrichParsedTransaction sms_hash=$dedupeKey updated=$updated',
    );
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
    // Include one day before today as a buffer for timezone edge cases.
    final from = today.subtract(const Duration(days: 1));
    final futureDate = today.add(Duration(days: daysAhead));
    final fromIso = toIsoDateString(from);
    final futureIso = toIsoDateString(futureDate);
    final db = await database;

    final rows = await db.query(
      tableRecurringExpenses,
      where:
          'next_due_date IS NOT NULL AND next_due_date != ? AND '
          'date(next_due_date) >= date(?) AND date(next_due_date) <= date(?)',
      whereArgs: <String>['', fromIso, futureIso],
      orderBy: 'next_due_date ASC',
    );

    debugPrint(
      '[DB] getUpcomingPayments from=$fromIso future=$futureIso raw=${rows.length}',
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

  Future<void> _migrateExpensesSubscriptionColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableExpenses)');
    final names = columns.map((row) => row['name'] as String).toSet();

    if (!names.contains('is_subscription')) {
      await db.execute(
        'ALTER TABLE $tableExpenses ADD COLUMN is_subscription INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('subscription_id')) {
      await db.execute(
        'ALTER TABLE $tableExpenses ADD COLUMN subscription_id INTEGER',
      );
    }
    // Add merchant index for fast subscription lookups.
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_merchant
      ON $tableExpenses(merchant)
    ''');
    debugPrint('[DB] expenses: subscription columns migrated');
  }

  Future<void> _createSubscriptionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSubscriptions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        frequency TEXT NOT NULL,
        last_paid_date TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        confidence_score TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_merchant
      ON $tableSubscriptions(merchant)
    ''');
    debugPrint('[DB] subscriptions table ready');
  }

  // ── Subscription CRUD ─────────────────────────────────────────────────────

  /// Inserts a new subscription row and returns its id.
  Future<int> insertSubscription(DetectedSubscription sub) async {
    final db = await database;
    final id = await db.insert(tableSubscriptions, sub.toDbMap());
    debugPrint('[DB] insertSubscription id=$id merchant=${sub.merchant}');
    return id;
  }

  /// Updates an existing subscription (must have a valid id).
  Future<int> updateSubscription(DetectedSubscription sub) async {
    if (sub.id == null) throw ArgumentError('Subscription id required');
    final db = await database;
    final updated = await db.update(
      tableSubscriptions,
      sub.toDbMap(),
      where: 'id = ?',
      whereArgs: <Object>[sub.id!],
    );
    debugPrint('[DB] updateSubscription id=${sub.id} updated=$updated');
    return updated;
  }

  /// Returns the subscription for [merchant], or null if not found.
  Future<DetectedSubscription?> getSubscriptionByMerchant(
    String merchant,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableSubscriptions,
      where: 'merchant = ?',
      whereArgs: <Object>[merchant.toUpperCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DetectedSubscription.fromMap(rows.first);
  }

  /// All active subscriptions ordered by next_due_date.
  Future<List<DetectedSubscription>> getAllSubscriptions({
    bool activeOnly = true,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableSubscriptions,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'next_due_date ASC',
    );
    debugPrint('[DB] getAllSubscriptions count=${rows.length}');
    return rows.map(DetectedSubscription.fromMap).toList();
  }

  /// Subscriptions whose next_due_date falls within the next [daysAhead] days.
  Future<List<DetectedSubscription>> getUpcomingSubscriptions({
    int daysAhead = 7,
  }) async {
    final now = DateTime.now();
    final today = dateOnly(now);
    // One-day buffer so today's due subscriptions are never missed.
    final from = today.subtract(const Duration(days: 1));
    final future = today.add(Duration(days: daysAhead));
    final db = await database;
    final rows = await db.query(
      tableSubscriptions,
      where:
          'is_active = 1 AND '
          'date(next_due_date) >= date(?) AND date(next_due_date) <= date(?)',
      whereArgs: <String>[
        toIsoDateString(from),
        toIsoDateString(future),
      ],
      orderBy: 'next_due_date ASC',
    );
    debugPrint('[DB] getUpcomingSubscriptions count=${rows.length}');
    return rows.map(DetectedSubscription.fromMap).toList();
  }

  /// Recent debit expenses for a given merchant — used for pattern detection.
  /// Capped at [limit] rows, most recent first.
  Future<List<Map<String, Object?>>> getExpensesByMerchant(
    String merchant, {
    int limit = 10,
  }) async {
    final db = await database;
    return db.query(
      tableExpenses,
      columns: <String>['id', 'amount', 'transaction_time', 'date'],
      where: 'merchant = ? AND transaction_type = ?',
      whereArgs: <Object>[merchant, 'debit'],
      orderBy: 'COALESCE(transaction_time, date) DESC',
      limit: limit,
    );
  }

  /// Links an expense row to a subscription.
  Future<void> linkExpenseToSubscription(
    int expenseId,
    int subscriptionId,
  ) async {
    final db = await database;
    await db.update(
      tableExpenses,
      <String, Object?>{
        'is_subscription': 1,
        'subscription_id': subscriptionId,
      },
      where: 'id = ?',
      whereArgs: <Object>[expenseId],
    );
    debugPrint(
      '[DB] linkExpenseToSubscription expenseId=$expenseId subId=$subscriptionId',
    );
  }

  Future<void> _createUserProfileTable(Database db) async {    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserProfile(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    debugPrint('[DB] user_profile table ready');
  }

  /// Inserts or updates the single user profile row.
  Future<void> insertOrUpdateUser(String name) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(tableUserProfile, limit: 1);
    if (rows.isEmpty) {
      await db.insert(tableUserProfile, <String, Object?>{
        'id': 1,
        'name': name,
        'created_at': now,
      });
      debugPrint('[USER] Inserted in DB: $name');
    } else {
      await db.update(
        tableUserProfile,
        <String, Object?>{'name': name},
        where: 'id = ?',
        whereArgs: <Object>[1],
      );
      debugPrint('[USER] Updated in DB: $name');
    }
  }

  /// Returns the stored user name, or "User" if none exists.
  Future<String> getUserName() async {
    final db = await database;
    final rows = await db.query(tableUserProfile, limit: 1);
    if (rows.isEmpty) {
      debugPrint('[USER] No profile found — returning default');
      return 'User';
    }
    final name = rows.first['name'] as String;
    debugPrint('[USER] Loaded from DB: $name');
    return name;
  }

  Future<void> logDebugDashboard() => logRecurringDebugDashboard(this);

  // ── Confirmation migration ─────────────────────────────────────────────────

  Future<void> _migrateExpensesConfirmationColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableExpenses)');
    final names = columns.map((row) => row['name'] as String).toSet();

    if (!names.contains('confirmation_status')) {
      await db.execute(
        "ALTER TABLE $tableExpenses "
        "ADD COLUMN confirmation_status TEXT NOT NULL DEFAULT 'confirmed'",
      );
      // Existing rows are already trusted — mark all confirmed.
      await db.execute(
        "UPDATE $tableExpenses SET confirmation_status = 'confirmed'",
      );
    }
    if (!names.contains('confidence_score')) {
      await db.execute(
        "ALTER TABLE $tableExpenses "
        "ADD COLUMN confidence_score TEXT NOT NULL DEFAULT 'medium'",
      );
    }
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_confirmation
      ON $tableExpenses(confirmation_status)
    ''');
    debugPrint('[DB] expenses: confirmation columns migrated');
  }

  // ── Merchant preferences table ────────────────────────────────────────────

  Future<void> _createMerchantPreferencesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMerchantPreferences(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL UNIQUE,
        is_trusted INTEGER NOT NULL DEFAULT 0,
        last_confirmed_at TEXT NOT NULL
      )
    ''');
    debugPrint('[DB] merchant_preferences table ready');
  }

  // ── Merchant preference CRUD ──────────────────────────────────────────────

  /// Returns the preference for [merchant] (normalised to uppercase), or null.
  Future<MerchantPreference?> getMerchantPreference(String merchant) async {
    final db = await database;
    final rows = await db.query(
      tableMerchantPreferences,
      where: 'merchant = ?',
      whereArgs: <Object>[merchant.toUpperCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MerchantPreference.fromMap(rows.first);
  }

  /// Upserts the trust flag for [merchant].
  Future<void> setMerchantTrusted(String merchant, {required bool trusted}) async {
    final key = merchant.toUpperCase();
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert(
      '''
      INSERT INTO $tableMerchantPreferences (merchant, is_trusted, last_confirmed_at)
      VALUES (?, ?, ?)
      ON CONFLICT(merchant) DO UPDATE
        SET is_trusted = excluded.is_trusted,
            last_confirmed_at = excluded.last_confirmed_at
      ''',
      <Object>[key, trusted ? 1 : 0, now],
    );
    debugPrint('[DB] setMerchantTrusted merchant=$key trusted=$trusted');
  }

  // ── Confirmation status helpers ───────────────────────────────────────────

  /// Updates only the confirmation_status (and optionally confidence_score).
  Future<void> updateConfirmationStatus(
    int expenseId,
    String status, {
    String? confidenceScore,
  }) async {
    final db = await database;
    final data = <String, Object?>{'confirmation_status': status};
    if (confidenceScore != null) data['confidence_score'] = confidenceScore;
    await db.update(
      tableExpenses,
      data,
      where: 'id = ?',
      whereArgs: <Object>[expenseId],
    );
    debugPrint(
      '[DB] updateConfirmationStatus id=$expenseId status=$status',
    );
  }

  /// All expenses excluding ignored ones, most-recent first.
  Future<List<Expense>> getVisibleExpenses() async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      where: "confirmation_status != 'ignored'",
      orderBy: 'COALESCE(transaction_time, date) DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  /// Only confirmed expenses — used for analytics totals.
  Future<List<Expense>> getConfirmedExpenses() async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      where: "confirmation_status = 'confirmed'",
      orderBy: 'COALESCE(transaction_time, date) DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  /// Only pending expenses — used for the review banner.
  Future<List<Expense>> getPendingExpenses() async {
    final db = await database;
    final rows = await db.query(
      tableExpenses,
      where: "confirmation_status = 'pending'",
      orderBy: 'COALESCE(transaction_time, date) DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }
}
