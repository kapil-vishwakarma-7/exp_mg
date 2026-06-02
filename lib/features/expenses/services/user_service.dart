import '../database/database_helper.dart';

/// Service layer that wraps user profile DB operations.
class UserService {
  UserService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Returns the stored user name, or "User" if none exists.
  Future<String> getUserName() => _db.getUserName();

  /// Persists [name] to the user_profile table (insert or update).
  Future<void> updateUserName(String name) => _db.insertOrUpdateUser(name);
}
