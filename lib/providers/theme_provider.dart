import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:planova/services/shared_prefs_service.dart';

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
  String _todoHeaderRegex = r'^#{1,2}\s+.*(Todos?|Tasks?)';
  String _eventHeaderRegex = r'^#{1,2}\s+.*Events?';
  String _logHeaderRegex = r'^#{1,2}\s+.*(Journal|Logs?)';
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
  static const String _logHeaderRegexKey = 'log_header_regex';

  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;
  String? get customStoragePath => _customStoragePath;
  String get dailyTemplate => _dailyTemplate;
  bool get widgetDarkTheme => _widgetDarkTheme;
  double get widgetTransparency => _widgetTransparency;
  String get todoHeaderRegex => _todoHeaderRegex;
  String get eventHeaderRegex => _eventHeaderRegex;
  String get logHeaderRegex => _logHeaderRegex;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  final Completer<void> _initCompleter = Completer<void>();

  ThemeProvider() {
    Log.i('🚀 ThemeProvider: Constructor called');
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _loadTheme(),
        _loadAppTheme(),
        _loadStoragePath(),
        _loadTemplate(),
        _loadWidgetTheme(),
        _loadWidgetTransparency(),
        _loadTodoHeaderRegex(),
        _loadEventHeaderRegex(),
        _loadLogHeaderRegex(),
      ]).timeout(const Duration(seconds: 10));
    } catch (e) {
      Log.e('❌ ThemeProvider: Initialization error (using defaults)', error: e);
    }

    _isInitialized = true;
    _initCompleter.complete();
    Log.i('🚀 ThemeProvider: Initialization completed');
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    final prefs = SharedPrefsService.instance;
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
  }

  Future<void> _loadAppTheme() async {
    final prefs = SharedPrefsService.instance;
    final themeIndex = prefs.getInt(_appThemeKey) ?? AppTheme.gruvbox.index;
    _appTheme = AppTheme.values[themeIndex];
  }

  Future<void> _loadStoragePath() async {
    Log.d('🔍 ThemeProvider: Loading storage path...');
    final prefs = SharedPrefsService.instance;
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
    final prefs = SharedPrefsService.instance;
    _dailyTemplate = prefs.getString(_templateKey) ?? _getDefaultTemplate();
  }

  Future<void> _loadWidgetTheme() async {
    final prefs = SharedPrefsService.instance;

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
    final prefs = SharedPrefsService.instance;

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
    final prefs = SharedPrefsService.instance;
    _todoHeaderRegex = prefs.getString(_todoHeaderRegexKey) ?? r'^#{1,2}\s+.*(Todos?|Tasks?)';
  }

  Future<void> _loadEventHeaderRegex() async {
    final prefs = SharedPrefsService.instance;
    _eventHeaderRegex =
        prefs.getString(_eventHeaderRegexKey) ?? r'^#{1,2}\s+.*Events?';
  }

  Future<void> _loadLogHeaderRegex() async {
    final prefs = SharedPrefsService.instance;
    _logHeaderRegex =
        prefs.getString(_logHeaderRegexKey) ?? r'^#{1,2}\s+.*(Journal|Logs?)';
  }

  String _getDefaultTemplate() {
    return '''# 📅 Events

# ✅ Todos

# 📝 Logs

# 🗒️ Notes
''';
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = SharedPrefsService.instance;
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    final prefs = SharedPrefsService.instance;
    await prefs.setInt(_appThemeKey, theme.index);
    notifyListeners();

    await WidgetService.updateWidgetColors();
  }

  Future<void> setStoragePath(String? path) async {
    Log.d('💾 ThemeProvider: Setting storage path to: $path');
    _customStoragePath = path;
    final prefs = SharedPrefsService.instance;
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
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_templateKey, template);
    notifyListeners();
  }

  Future<void> setWidgetTheme(bool isDark) async {
    _widgetDarkTheme = isDark;
    final prefs = SharedPrefsService.instance;
    await prefs.setBool(AppConstants.widgetThemeKey, isDark);
    notifyListeners();

    // Update widget with new theme
    await _updateWidgetWithNewTheme(isDark);
  }

  Future<void> setWidgetTransparency(double transparency) async {
    _widgetTransparency = transparency.clamp(0.0, 1.0);
    final prefs = SharedPrefsService.instance;
    await prefs.setDouble(
        AppConstants.widgetTransparencyKey, _widgetTransparency);
    notifyListeners();

    // Update widget with new transparency
    await _updateWidgetWithNewTransparency(_widgetTransparency);
  }

  Future<void> setTodoHeaderRegex(String regex) async {
    _todoHeaderRegex = regex;
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_todoHeaderRegexKey, regex);
    notifyListeners();
  }

  Future<void> setEventHeaderRegex(String regex) async {
    _eventHeaderRegex = regex;
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_eventHeaderRegexKey, regex);
    notifyListeners();
  }

  Future<void> setLogHeaderRegex(String regex) async {
    _logHeaderRegex = regex;
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_logHeaderRegexKey, regex);
    notifyListeners();
  }

  String getDisplayStoragePath() {
    if (_customStoragePath != null) {
      return _customStoragePath!;
    }
    return 'Default (App Documents/Org)';
  }

  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    await _initCompleter.future.timeout(const Duration(seconds: 10));
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
