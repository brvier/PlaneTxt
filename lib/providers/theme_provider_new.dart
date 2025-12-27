import 'package:flutter/material.dart';
import 'package:planova/constants/app_constants.dart';
import 'package:planova/themes/app_themes.dart';
import 'package:planova/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing theme-related settings
class ThemeProvider extends ChangeNotifier {
  final Logger _logger = Logger('ThemeProvider');

  ThemeMode _themeMode = ThemeMode.system;
  AppTheme _appTheme = AppTheme.gruvbox;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  AppTheme get appTheme => _appTheme;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _logger.entry('constructor');
    _initialize();
    _logger.exit('constructor');
  }

  /// Initialize theme provider
  Future<void> _initialize() async {
    try {
      _logger.entry('_initialize');

      await Future.wait([
        _loadTheme(),
        _loadAppTheme(),
      ]);

      _isInitialized = true;
      _logger.info('ThemeProvider: Initialization completed');
      notifyListeners();

      _logger.exit('_initialize');
    } catch (e, stackTrace) {
      _logger.error('ThemeProvider: Error during initialization',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Load theme mode from preferences
  Future<void> _loadTheme() async {
    _logger.entry('_loadTheme');

    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(AppConstants.themeModeKey) ?? 0;
      _themeMode = ThemeMode.values[themeIndex];
      _logger.debug('Loaded theme mode: $_themeMode');
    } catch (e, stackTrace) {
      _logger.error('Error loading theme mode',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadTheme');
  }

  /// Load app theme from preferences
  Future<void> _loadAppTheme() async {
    _logger.entry('_loadAppTheme');

    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex =
          prefs.getInt(AppConstants.appThemeKey) ?? AppTheme.gruvbox.index;
      _appTheme = AppTheme.values[themeIndex];
      _logger.debug('Loaded app theme: $_appTheme');
    } catch (e, stackTrace) {
      _logger.error('Error loading app theme',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadAppTheme');
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _logger.entry('setThemeMode', params: {'mode': mode});

    try {
      _themeMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.themeModeKey, mode.index);

      _logger.debug('Theme mode saved: $mode');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error setting theme mode',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setThemeMode');
  }

  /// Set app theme
  Future<void> setAppTheme(AppTheme theme) async {
    _logger.entry('setAppTheme', params: {'theme': theme});

    try {
      _appTheme = theme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.appThemeKey, theme.index);

      _logger.debug('App theme saved: $theme');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error setting app theme',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setAppTheme');
  }

  /// Get light theme data
  ThemeData get lightTheme {
    return AppThemes.getTheme(_appTheme).lightTheme;
  }

  /// Get dark theme data
  ThemeData get darkTheme {
    return AppThemes.getTheme(_appTheme).darkTheme;
  }

  @override
  void dispose() {
    _logger.entry('dispose');
    super.dispose();
    _logger.exit('dispose');
  }
}
