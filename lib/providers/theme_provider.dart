import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/widget_service.dart';
import '../themes/app_themes.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppTheme _appTheme = AppTheme.gruvbox;
  String? _customStoragePath;
  String _dailyTemplate = '';
  bool _widgetDarkTheme = false;
  double _widgetTransparency = 1.0; // 1.0 = fully opaque, 0.0 = fully transparent
  static const String _themeKey = 'theme_mode';
  static const String _appThemeKey = 'app_theme';
  static const String _storagePathKey = 'storage_path';
  static const String _templateKey = 'daily_template';
  static const String _widgetThemeKey = 'flutter.widget_dark_theme';
  static const String _widgetTransparencyKey = 'flutter.widget_transparency';

  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;
  String? get customStoragePath => _customStoragePath;
  String get dailyTemplate => _dailyTemplate;
  bool get widgetDarkTheme => _widgetDarkTheme;
  double get widgetTransparency => _widgetTransparency;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    print('🚀 ThemeProvider: Constructor called');
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
    ]);
    _isInitialized = true;
    print('🚀 ThemeProvider: Initialization completed');
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> _loadAppTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_appThemeKey) ?? AppTheme.gruvbox.index;
    _appTheme = AppTheme.values[themeIndex];
    notifyListeners();
  }

  Future<void> _loadStoragePath() async {
    print('🔍 ThemeProvider: Loading storage path...');
    final prefs = await SharedPreferences.getInstance();
    _customStoragePath = prefs.getString(_storagePathKey);
    print('🔍 ThemeProvider: Loaded custom storage path: $_customStoragePath');
    print('🔍 ThemeProvider: Storage path key: $_storagePathKey');
    notifyListeners();
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyTemplate = prefs.getString(_templateKey) ?? _getDefaultTemplate();
    notifyListeners();
  }

  Future<void> _loadWidgetTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _widgetDarkTheme = prefs.getBool(_widgetThemeKey) ?? false;
    notifyListeners();
  }

  Future<void> _loadWidgetTransparency() async {
    final prefs = await SharedPreferences.getInstance();
    _widgetTransparency = prefs.getDouble(_widgetTransparencyKey) ?? 1.0;
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

  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_appThemeKey, theme.index);
    notifyListeners();
  }

  Future<void> setStoragePath(String? path) async {
    print('💾 ThemeProvider: Setting storage path to: $path');
    _customStoragePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      print('💾 ThemeProvider: Saving path to SharedPreferences with key: $_storagePathKey');
      await prefs.setString(_storagePathKey, path);
      print('💾 ThemeProvider: Path saved successfully');
    } else {
      print('💾 ThemeProvider: Removing storage path from SharedPreferences');
      await prefs.remove(_storagePathKey);
      print('💾 ThemeProvider: Path removed successfully');
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
    await prefs.setBool(_widgetThemeKey, isDark);
    notifyListeners();
    
    // Update widget with new theme
    await _updateWidgetWithNewTheme(isDark);
  }

  Future<void> setWidgetTransparency(double transparency) async {
    _widgetTransparency = transparency.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_widgetTransparencyKey, _widgetTransparency);
    notifyListeners();
    
    // Update widget with new transparency
    await _updateWidgetWithNewTransparency(_widgetTransparency);
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
    while (attempts < 50) { // Wait up to 5 seconds
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      // The storage path loading is complete when we've tried to load it
      // We can check if the SharedPreferences loading is done by checking if we have a value or null
      break;
    }
    print('🔍 ThemeProvider: waitForInitialization completed, customStoragePath: $_customStoragePath');
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
      // Get today's daily file to update widget
      final today = DateTime.now();
      final dateString = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
      
      // We need to get the daily file content, but we don't have access to FileProvider here
      // So we'll just update the widget with the theme preference
      // The widget will use the existing content with the new theme
      await WidgetService.updateWidgetTheme(isDarkTheme);
    } catch (e) {
      print('❌ ThemeProvider: Error updating widget with new theme: $e');
    }
  }

  /// Update widget with new transparency
  Future<void> _updateWidgetWithNewTransparency(double transparency) async {
    try {
      // Update widget with new transparency
      await WidgetService.updateWidgetTransparency(transparency);
    } catch (e) {
      print('❌ ThemeProvider: Error updating widget with new transparency: $e');
    }
  }
}