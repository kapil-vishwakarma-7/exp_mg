import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'is_dark';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Loads persisted theme preference from SharedPreferences.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    debugPrint('[THEME] Loaded — isDark=$isDark');
    notifyListeners();
  }

  /// Persists and applies the new theme mode.
  Future<void> toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDark);
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    debugPrint('[THEME] Toggled — isDark=$isDark');
    notifyListeners();
  }
}
