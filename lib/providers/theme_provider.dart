import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String? _customStoragePath;
  String _dailyTemplate = '';
  static const String _themeKey = 'theme_mode';
  static const String _storagePathKey = 'storage_path';
  static const String _templateKey = 'daily_template';

  ThemeMode get themeMode => _themeMode;
  String? get customStoragePath => _customStoragePath;
  String get dailyTemplate => _dailyTemplate;

  ThemeProvider() {
    _loadTheme();
    _loadStoragePath();
    _loadTemplate();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> _loadStoragePath() async {
    final prefs = await SharedPreferences.getInstance();
    _customStoragePath = prefs.getString(_storagePathKey);
    notifyListeners();
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyTemplate = prefs.getString(_templateKey) ?? _getDefaultTemplate();
    notifyListeners();
  }

  String _getDefaultTemplate() {
    return '''## Events

## Tasks

## Journal

## Notes
''';
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setStoragePath(String? path) async {
    _customStoragePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_storagePathKey, path);
    } else {
      await prefs.remove(_storagePathKey);
    }
    notifyListeners();
  }

  Future<void> setDailyTemplate(String template) async {
    _dailyTemplate = template;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_templateKey, template);
    notifyListeners();
  }

  String getDisplayStoragePath() {
    if (_customStoragePath != null) {
      return _customStoragePath!;
    }
    return 'Default (Documents/Org)';
  }

  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        // Gruvbox Light colors
        primary: Color(0xFF458588), // blue
        onPrimary: Color(0xFFFFFFFF), // white for better contrast
        secondary: Color(0xFF689D6A), // green
        onSecondary: Color(0xFFFFFFFF), // white for better contrast
        tertiary: Color(0xFFB16286), // purple
        onTertiary: Color(0xFFFFFFFF), // white for better contrast
        error: Color(0xFFCC241D), // red
        onError: Color(0xFFFFFFFF), // white for better contrast
        surface: Color(0xFFFBF1C7), // bg0
        onSurface: Color(0xFF3C3836), // fg0
        surfaceContainerHighest: Color(0xFFF2E5BC), // bg1
        onSurfaceVariant: Color(0xFF665C54), // fg1
        outline: Color(0xFF928374), // gray
        background: Color(0xFFFBF1C7), // bg0
        onBackground: Color(0xFF3C3836), // fg0
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFF2E5BC), // bg1
        foregroundColor: Color(0xFF3C3836), // fg0
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        // Gruvbox Dark colors
        primary: Color(0xFF83A598), // blue
        onPrimary: Color(0xFF000000), // black for better contrast
        secondary: Color(0xFFB8BB26), // green
        onSecondary: Color(0xFF000000), // black for better contrast
        tertiary: Color(0xFFD3869B), // purple
        onTertiary: Color(0xFF000000), // black for better contrast
        error: Color(0xFFFB4934), // red
        onError: Color(0xFF000000), // black for better contrast
        surface: Color(0xFF282828), // bg0
        onSurface: Color(0xFFEBDBB2), // fg0
        surfaceContainerHighest: Color(0xFF3C3836), // bg1
        onSurfaceVariant: Color(0xFFA89984), // fg1
        outline: Color(0xFF928374), // gray
        background: Color(0xFF282828), // bg0
        onBackground: Color(0xFFEBDBB2), // fg0
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF3C3836), // bg1
        foregroundColor: Color(0xFFEBDBB2), // fg0
      ),
    );
  }
}