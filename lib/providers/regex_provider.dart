import 'package:flutter/material.dart';
import 'package:planova/constants/app_constants.dart';
import 'package:planova/utils/exceptions.dart';
import 'package:planova/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing regex patterns for parsing content
class RegexProvider extends ChangeNotifier {
  final Logger _logger = Logger('RegexProvider');

  String _todoHeaderRegex = AppConstants.defaultTodoHeaderRegex;
  String _eventHeaderRegex = AppConstants.defaultEventHeaderRegex;
  bool _isInitialized = false;

  String get todoHeaderRegex => _todoHeaderRegex;
  String get eventHeaderRegex => _eventHeaderRegex;
  bool get isInitialized => _isInitialized;

  RegexProvider() {
    _logger.entry('constructor');
    _initialize();
    _logger.exit('constructor');
  }

  /// Initialize regex provider
  Future<void> _initialize() async {
    try {
      _logger.entry('_initialize');

      await Future.wait([
        _loadTodoHeaderRegex(),
        _loadEventHeaderRegex(),
      ]);

      _isInitialized = true;
      _logger.info('RegexProvider: Initialization completed');
      notifyListeners();

      _logger.exit('_initialize');
    } catch (e, stackTrace) {
      _logger.error('RegexProvider: Error during initialization',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Load todo header regex
  Future<void> _loadTodoHeaderRegex() async {
    _logger.entry('_loadTodoHeaderRegex');

    try {
      final prefs = await SharedPreferences.getInstance();
      _todoHeaderRegex = prefs.getString(AppConstants.todoHeaderRegexKey) ??
          AppConstants.defaultTodoHeaderRegex;
      _logger.debug('Loaded todo header regex: $_todoHeaderRegex');
    } catch (e, stackTrace) {
      _logger.error('Error loading todo header regex',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadTodoHeaderRegex');
  }

  /// Load event header regex
  Future<void> _loadEventHeaderRegex() async {
    _logger.entry('_loadEventHeaderRegex');

    try {
      final prefs = await SharedPreferences.getInstance();
      _eventHeaderRegex = prefs.getString(AppConstants.eventHeaderRegexKey) ??
          AppConstants.defaultEventHeaderRegex;
      _logger.debug('Loaded event header regex: $_eventHeaderRegex');
    } catch (e, stackTrace) {
      _logger.error('Error loading event header regex',
          error: e, stackTrace: stackTrace);
    }

    _logger.exit('_loadEventHeaderRegex');
  }

  /// Set todo header regex
  Future<void> setTodoHeaderRegex(String regex) async {
    _logger.entry('setTodoHeaderRegex', params: {'regex': regex});

    try {
      // Validate regex pattern
      try {
        RegExp(regex);
      } catch (e) {
        throw ValidationException('Invalid regex pattern',
            field: 'todoHeaderRegex', value: regex);
      }

      _todoHeaderRegex = regex;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.todoHeaderRegexKey, regex);

      _logger.debug('Todo header regex saved: $regex');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error setting todo header regex',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setTodoHeaderRegex');
  }

  /// Set event header regex
  Future<void> setEventHeaderRegex(String regex) async {
    _logger.entry('setEventHeaderRegex', params: {'regex': regex});

    try {
      // Validate regex pattern
      try {
        RegExp(regex);
      } catch (e) {
        throw ValidationException('Invalid regex pattern',
            field: 'eventHeaderRegex', value: regex);
      }

      _eventHeaderRegex = regex;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.eventHeaderRegexKey, regex);

      _logger.debug('Event header regex saved: $regex');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error setting event header regex',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('setEventHeaderRegex');
  }

  /// Reset regex patterns to defaults
  Future<void> resetToDefaults() async {
    _logger.entry('resetToDefaults');

    try {
      await Future.wait([
        setTodoHeaderRegex(AppConstants.defaultTodoHeaderRegex),
        setEventHeaderRegex(AppConstants.defaultEventHeaderRegex),
      ]);

      _logger.debug('Regex patterns reset to defaults');
    } catch (e, stackTrace) {
      _logger.error('Error resetting regex patterns',
          error: e, stackTrace: stackTrace);
      rethrow;
    }

    _logger.exit('resetToDefaults');
  }

  @override
  void dispose() {
    _logger.entry('dispose');
    super.dispose();
    _logger.exit('dispose');
  }
}
