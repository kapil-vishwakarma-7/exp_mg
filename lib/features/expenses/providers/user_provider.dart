import 'package:flutter/foundation.dart';

import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({UserService? service})
      : _service = service ?? UserService();

  final UserService _service;
  String _name = 'User';
  bool _disposed = false;

  String get name => _name;

  /// Loads the user name from SQLite. Safe to call after construction.
  Future<void> loadUser() async {
    _name = await _service.getUserName();
    debugPrint('[USER] Loaded from DB: $_name');
    _safeNotify();
  }

  /// Validates, persists, and broadcasts the new name.
  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    debugPrint('[USER] Updating name...');
    _name = trimmed;
    await _service.updateUserName(_name);
    debugPrint('[USER] Updated in DB: $_name');
    debugPrint('[USER] Notifying listeners safely');
    _safeNotify();
  }

  /// Calls [notifyListeners] only if this notifier has not been disposed.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
