import 'package:flutter/material.dart';
import 'package:planetxt/constants/app_constants.dart';
import 'package:planetxt/services/widget_service.dart';
import 'package:planetxt/utils/logger.dart';
import 'package:planetxt/services/shared_prefs_service.dart';

/// Provider for managing widget-related settings
class WidgetProvider extends ChangeNotifier {
  final Logger _logger = Logger('WidgetProvider');

  bool _widgetDarkTheme = false;
  double _widgetTransparency = 1.0;
  bool _isInitialized = false;

  bool get widgetDarkTheme => _widgetDarkTheme;
  double get widgetTransparency => _widgetTransparency;
  bool get isInitialized => _isInitialized;

  WidgetProvider() {
    _logger.entry('constructor');
    _initialize();
    _logger.exit('constructor');
  }

  /// Initialize widget provider
  Future<void> _initialize() async {
    try {
      _logger.entry('_initialize');

      await Future.wait([
        _loadWidgetTheme(),
        _loadWidgetTransparency(),
      ]);

      _isInitialized = true;
      _logger.info('WidgetProvider: Initialization completed');
      notifyListeners();

      _logger.exit('_initialize');
    } catch (e, stackTrace) {
      _logger.error('WidgetProvider: Error during initialization',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Load widget theme preference
  Future<void> _loadWidgetTheme() async {
    _logger.entry('_loadWidgetTheme');

    try {
      final prefs = SharedPrefsService.instance;
      _widgetDarkTheme = prefs.getBool(AppConstants.widgetThemeKey) ?? false;
      _logger.debug('Loaded widget theme: $_widgetDarkTheme');
    } catch (e, stackTrace) {
      _logger.error('Error loading widget theme',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadWidgetTheme');
  }

  /// Load widget transparency preference
  Future<void> _loadWidgetTransparency() async {
    _logger.entry('_loadWidgetTransparency');

    try {
      final prefs = SharedPrefsService.instance;
      _widgetTransparency =
          prefs.getDouble(AppConstants.widgetTransparencyKey) ?? 1.0;
      _logger.debug('Loaded widget transparency: $_widgetTransparency');
    } catch (e, stackTrace) {
      _logger.error('Error loading widget transparency',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadWidgetTransparency');
  }

  /// Set widget theme
  Future<void> setWidgetTheme(bool isDark) async {
    _logger.entry('setWidgetTheme', params: {'isDark': isDark});

    try {
      _widgetDarkTheme = isDark;
      final prefs = SharedPrefsService.instance;
      await prefs.setBool(AppConstants.widgetThemeKey, isDark);

      _logger.debug('Widget theme saved: $isDark');
      notifyListeners();

      // Update widget with new theme
      await _updateWidgetWithNewTheme(isDark);
    } catch (e, stackTrace) {
      _logger.error('Error setting widget theme',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setWidgetTheme');
  }

  /// Set widget transparency
  Future<void> setWidgetTransparency(double transparency) async {
    _logger
        .entry('setWidgetTransparency', params: {'transparency': transparency});

    try {
      _widgetTransparency = transparency.clamp(0.0, 1.0);
      final prefs = SharedPrefsService.instance;
      await prefs.setDouble(
          AppConstants.widgetTransparencyKey, _widgetTransparency);

      _logger.debug('Widget transparency saved: $_widgetTransparency');
      notifyListeners();

      // Update widget with new transparency
      await _updateWidgetWithNewTransparency(_widgetTransparency);
    } catch (e, stackTrace) {
      _logger.error('Error setting widget transparency',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setWidgetTransparency');
  }

  /// Update widget with new theme
  Future<void> _updateWidgetWithNewTheme(bool isDarkTheme) async {
    _logger.entry('_updateWidgetWithNewTheme',
        params: {'isDarkTheme': isDarkTheme});

    try {
      await WidgetService.updateWidgetTheme(isDarkTheme);
      _logger.debug('Widget updated with new theme');
    } catch (e, stackTrace) {
      _logger.error('Error updating widget with new theme',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_updateWidgetWithNewTheme');
  }

  /// Update widget with new transparency
  Future<void> _updateWidgetWithNewTransparency(double transparency) async {
    _logger.entry('_updateWidgetWithNewTransparency',
        params: {'transparency': transparency});

    try {
      await WidgetService.updateWidgetTransparency(transparency);
      _logger.debug('Widget updated with new transparency');
    } catch (e, stackTrace) {
      _logger.error('Error updating widget with new transparency',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_updateWidgetWithNewTransparency');
  }

  @override
  void dispose() {
    _logger.entry('dispose');
    super.dispose();
    _logger.exit('dispose');
  }
}
