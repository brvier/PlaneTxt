import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:planova/constants/app_constants.dart';
import 'package:planova/utils/logger.dart';

/// Provider for managing general app settings
class SettingsProvider extends ChangeNotifier {
  final Logger _logger = Logger('SettingsProvider');

  String? _customStoragePath;
  String _dailyTemplate = '';
  bool _isInitialized = false;

  String? get customStoragePath => _customStoragePath;
  String get dailyTemplate => _dailyTemplate;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    _logger.entry('constructor');
    _initialize();
    _logger.exit('constructor');
  }

  /// Initialize settings provider
  Future<void> _initialize() async {
    try {
      _logger.entry('_initialize');

      await Future.wait([
        _loadStoragePath(),
        _loadTemplate(),
      ]);

      _isInitialized = true;
      _logger.info('SettingsProvider: Initialization completed');
      notifyListeners();

      _logger.exit('_initialize');
    } catch (e, stackTrace) {
      _logger.error('SettingsProvider: Error during initialization',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Load custom storage path
  Future<void> _loadStoragePath() async {
    _logger.entry('_loadStoragePath');

    try {
      final prefs = await SharedPreferences.getInstance();
      _customStoragePath = prefs.getString(AppConstants.storagePathKey);
      _logger.debug('Loaded custom storage path: $_customStoragePath');
      if (_customStoragePath != null && _customStoragePath!.isNotEmpty) {
        try {
          await HomeWidget.saveWidgetData<String>(
            AppConstants.storagePathKey,
            _customStoragePath!,
          );
        } catch (e, stackTrace) {
          _logger.warning('Failed to sync widget storage path on load',
              error: e, stackTrace: stackTrace);
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Error loading storage path',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadStoragePath');
  }

  /// Load daily template
  Future<void> _loadTemplate() async {
    _logger.entry('_loadTemplate');

    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyTemplate = prefs.getString(AppConstants.templateKey) ??
          AppConstants.defaultDailyTemplate;
      _logger
          .debug('Loaded daily template: ${_dailyTemplate.length} characters');
    } catch (e, stackTrace) {
      _logger.error('Error loading daily template',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadTemplate');
  }

  /// Set custom storage path
  Future<void> setStoragePath(String? path) async {
    _logger.entry('setStoragePath', params: {'path': path});

    try {
      _customStoragePath = path;
      final prefs = await SharedPreferences.getInstance();

      if (path != null) {
        await prefs.setString(AppConstants.storagePathKey, path);
        _logger.debug('Storage path saved: $path');
      } else {
        await prefs.remove(AppConstants.storagePathKey);
        _logger.debug('Storage path removed');
      }

      try {
        await HomeWidget.saveWidgetData<String>(
          AppConstants.storagePathKey,
          path ?? '',
        );
      } catch (e, stackTrace) {
        _logger.warning('Failed to sync widget storage path',
            error: e, stackTrace: stackTrace);
      }

      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error setting storage path',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setStoragePath');
  }

  /// Set daily template
  Future<void> setDailyTemplate(String template) async {
    _logger
        .entry('setDailyTemplate', params: {'templateLength': template.length});

    try {
      _dailyTemplate = template;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.templateKey, template);

      _logger.debug('Daily template saved: ${template.length} characters');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error setting daily template',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setDailyTemplate');
  }

  /// Get display storage path
  String getDisplayStoragePath() {
    if (_customStoragePath != null) {
      return _customStoragePath!;
    }
    return 'Default (App Documents/Org)';
  }

  /// Wait for initialization to complete
  Future<void> waitForInitialization() async {
    _logger.entry('waitForInitialization');

    int attempts = 0;
    while (attempts < AppConstants.maxInitializationAttempts) {
      await Future.delayed(AppConstants.initializationAttemptDelay);
      attempts++;

      if (_isInitialized) break;
    }

    _logger.debug(
        'waitForInitialization completed, customStoragePath: $_customStoragePath');
    _logger.exit('waitForInitialization');
  }

  @override
  void dispose() {
    _logger.entry('dispose');
    super.dispose();
    _logger.exit('dispose');
  }
}
