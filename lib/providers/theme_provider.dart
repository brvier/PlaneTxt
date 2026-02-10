import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:planova/constants/app_constants.dart';
import 'package:planova/services/widget_service.dart';
import 'package:planova/themes/app_themes.dart';
import 'package:planova/utils/logger.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppTheme _appTheme = AppTheme.gruvbox;
  String? _customStoragePath;
  String _dailyTemplate = '';
  bool _widgetDarkTheme = false;
  double _widgetTransparency =
      1.0; // 1.0 = fully opaque, 0.0 = fully transparent
  String _todoHeaderRegex = r'^##\s+Tasks?';
  String _eventHeaderRegex = r'^##\s+Events?';
  static const String _themeKey = 'theme_mode';
  static const String _appThemeKey = 'app_theme';
  static const String _storagePathKey = 'storage_path';
  static const String _templateKey = 'daily_template';
  // Legacy keys used by older versions (kept for migration).
  // Older code incorrectly included the `flutter.` prefix, which ends up being
  // double-prefixed on Android (`flutter.flutter.*`).
  static const String _legacyWidgetThemeKey = 'flutter.widget_dark_theme';
  static const String _legacyWidgetTransparencyKey =
      'flutter.widget_transparency';
  static const String _todoHeaderRegexKey = 'todo_header_regex';
  static const String _eventHeaderRegexKey = 'event_header_regex';

  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;
  String? get customStoragePath => _customStoragePath;
  String get dailyTemplate => _dailyTemplate;
  bool get widgetDarkTheme => _widgetDarkTheme;
  double get widgetTransparency => _widgetTransparency;
  String get todoHeaderRegex => _todoHeaderRegex;
  String get eventHeaderRegex => _eventHeaderRegex;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    Log.i('🚀 ThemeProvider: Constructor called');
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadTheme(),
      _loadAppTheme(),
      _loadStoragePath(),
      _loadTemplate(),
      _loadWidgetTheme(),
      _loadWidgetTransparency(),
      _loadTodoHeaderRegex(),
      _loadEventHeaderRegex(),
    ]);

    _isInitialized = true;
    Log.i('🚀 ThemeProvider: Initialization completed');
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
  }

  Future<void> _loadAppTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_appThemeKey) ?? AppTheme.gruvbox.index;
    _appTheme = AppTheme.values[themeIndex];
  }

  Future<void> _loadStoragePath() async {
    Log.d('🔍 ThemeProvider: Loading storage path...');
    final prefs = await SharedPreferences.getInstance();
    _customStoragePath = prefs.getString(_storagePathKey);
    Log.d('🔍 ThemeProvider: Loaded custom storage path: $_customStoragePath');
    Log.d('🔍 ThemeProvider: Storage path key: $_storagePathKey');
    if (_customStoragePath != null && _customStoragePath!.isNotEmpty) {
      try {
        await HomeWidget.saveWidgetData<String>(
          AppConstants.storagePathKey,
          _customStoragePath!,
        );
      } catch (e, stackTrace) {
        Log.w('⚠️ ThemeProvider: Failed to sync widget storage path on load',
            error: e, stackTrace: stackTrace);
      }
    }
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyTemplate = prefs.getString(_templateKey) ?? _getDefaultTemplate();
  }

  Future<void> _loadWidgetTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final current = prefs.getBool(AppConstants.widgetThemeKey);
    if (current != null) {
      _widgetDarkTheme = current;
      return;
    }

    final legacy = prefs.getBool(_legacyWidgetThemeKey);
    if (legacy != null) {
      _widgetDarkTheme = legacy;
      await prefs.setBool(AppConstants.widgetThemeKey, legacy);
      return;
    }

    _widgetDarkTheme = false;
  }

  Future<void> _loadWidgetTransparency() async {
    final prefs = await SharedPreferences.getInstance();

    final current = prefs.getDouble(AppConstants.widgetTransparencyKey);
    if (current != null) {
      _widgetTransparency = current;
      return;
    }

    final legacy = prefs.getDouble(_legacyWidgetTransparencyKey);
    if (legacy != null) {
      _widgetTransparency = legacy;
      await prefs.setDouble(AppConstants.widgetTransparencyKey, legacy);
      return;
    }

    _widgetTransparency = 1.0;
  }

  Future<void> _loadTodoHeaderRegex() async {
    final prefs = await SharedPreferences.getInstance();
    _todoHeaderRegex = prefs.getString(_todoHeaderRegexKey) ?? r'^##\s+Tasks?';
  }

  Future<void> _loadEventHeaderRegex() async {
    final prefs = await SharedPreferences.getInstance();
    _eventHeaderRegex =
        prefs.getString(_eventHeaderRegexKey) ?? r'^##\s+Events?';
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

  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_appThemeKey, theme.index);
    notifyListeners();

    await WidgetService.updateWidgetColors();
  }

  Future<void> setStoragePath(String? path) async {
    Log.d('💾 ThemeProvider: Setting storage path to: $path');
    _customStoragePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      Log.d(
          '💾 ThemeProvider: Saving path to SharedPreferences with key: $_storagePathKey');
      await prefs.setString(_storagePathKey, path);
      Log.d('💾 ThemeProvider: Path saved successfully');
    } else {
      Log.d('💾 ThemeProvider: Removing storage path from SharedPreferences');
      await prefs.remove(_storagePathKey);
      Log.d('💾 ThemeProvider: Path removed successfully');
    }
    try {
      await HomeWidget.saveWidgetData<String>(
        AppConstants.storagePathKey,
        path ?? '',
      );
    } catch (e, stackTrace) {
      Log.w('⚠️ ThemeProvider: Failed to sync widget storage path',
          error: e, stackTrace: stackTrace);
    }
    notifyListeners();
  }

  Future<void> setDailyTemplate(String template) async {
    _dailyTemplate = template;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_templateKey, template);
    notifyListeners();
  }

  Future<void> setWidgetTheme(bool isDark) async {
    _widgetDarkTheme = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.widgetThemeKey, isDark);
    notifyListeners();

    // Update widget with new theme
    await _updateWidgetWithNewTheme(isDark);
  }

  Future<void> setWidgetTransparency(double transparency) async {
    _widgetTransparency = transparency.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
        AppConstants.widgetTransparencyKey, _widgetTransparency);
    notifyListeners();

    // Update widget with new transparency
    await _updateWidgetWithNewTransparency(_widgetTransparency);
  }

  Future<void> setTodoHeaderRegex(String regex) async {
    _todoHeaderRegex = regex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todoHeaderRegexKey, regex);
    notifyListeners();
  }

  Future<void> setEventHeaderRegex(String regex) async {
    _eventHeaderRegex = regex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventHeaderRegexKey, regex);
    notifyListeners();
  }

  String getDisplayStoragePath() {
    if (_customStoragePath != null) {
      return _customStoragePath!;
    }
    return 'Default (App Documents/Org)';
  }

  Future<void> waitForInitialization() async {
    // Wait for the async initialization to complete
    int attempts = 0;
    while (attempts < 50) {
      // Wait up to 5 seconds
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      // The storage path loading is complete when we've tried to load it
      // We can check if the SharedPreferences loading is done by checking if we have a value or null
      break;
    }
    Log.d(
        '🔍 ThemeProvider: waitForInitialization completed, customStoragePath: $_customStoragePath');
  }

  ThemeData get lightTheme {
    return AppThemes.getTheme(_appTheme).lightTheme;
  }

  ThemeData get darkTheme {
    return AppThemes.getTheme(_appTheme).darkTheme;
  }

  /// Update widget with new theme
  Future<void> _updateWidgetWithNewTheme(bool isDarkTheme) async {
    try {
      // We need to get the daily file content, but we don't have access to FileProvider here
      // So we'll just update the widget with the theme preference
      // The widget will use the existing content with the new theme
      await WidgetService.updateWidgetTheme(isDarkTheme);
    } catch (e) {
      Log.e('❌ ThemeProvider: Error updating widget with new theme', error: e);
    }
  }

  /// Update widget with new transparency
  Future<void> _updateWidgetWithNewTransparency(double transparency) async {
    try {
      // Update widget with new transparency
      await WidgetService.updateWidgetTransparency(transparency);
    } catch (e) {
      Log.e('❌ ThemeProvider: Error updating widget with new transparency',
          error: e);
    }
  }
}
