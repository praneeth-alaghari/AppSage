import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service to manage app theme (light/dark mode)
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  final _storage = const FlutterSecureStorage();
  
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  /// Loads saved theme preference from storage
  Future<void> loadTheme() async {
    try {
      final savedTheme = await _storage.read(key: _themeKey);
      _isDarkMode = savedTheme == 'dark';
      notifyListeners();
    } catch (e) {
      // Default to light mode if loading fails
      _isDarkMode = false;
    }
  }
  
  /// Toggles between light and dark mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.write(key: _themeKey, value: _isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }
  
  /// Sets specific theme mode
  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    await _storage.write(key: _themeKey, value: _isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }
  
  /// Gets the current theme data
  ThemeData get themeData {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }
  
  /// Light theme configuration
  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue.shade600,
    scaffoldBackgroundColor: Colors.grey.shade50,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      titleTextStyle: const TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      bodySmall: TextStyle(color: Colors.black54),
    ),
  );
  
  /// Dark theme configuration
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue.shade400,
    scaffoldBackgroundColor: Colors.grey.shade900,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey.shade900,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.grey.shade800,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white70),
    ),
  );
}
