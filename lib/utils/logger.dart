import 'package:flutter/foundation.dart';
import 'package:planova/constants/app_constants.dart';
import 'package:planova/utils/exceptions.dart';

/// Log levels for structured logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Structured logging utility with levels and context
class Log {
  static LogLevel _currentLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  static bool _enableFileLogging = false;
  static bool _enableConsoleLogging = true;

  /// Configure logging behavior
  static void configure({
    LogLevel? level,
    bool enableFileLogging = false,
    bool enableConsoleLogging = true,
  }) {
    _currentLevel = level ?? _currentLevel;
    _enableFileLogging = enableFileLogging;
    _enableConsoleLogging = enableConsoleLogging;
  }

  /// Log debug message
  static void d(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message,
        tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  static void i(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message,
        tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  static void w(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message,
        tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  static void e(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message,
        tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log exception with full details
  static void exception(
    PlanovaException exception, {
    String? tag,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      exception.message,
      tag: tag ?? exception.runtimeType.toString(),
      error: exception.originalError,
      stackTrace: stackTrace,
    );

    if (exception.details != null) {
      _log(
        LogLevel.debug,
        'Exception details: ${exception.details}',
        tag: tag ?? exception.runtimeType.toString(),
      );
    }
  }

  /// Log method entry (for debugging)
  static void entry(String methodName, {Map<String, dynamic>? params}) {
    final buffer = StringBuffer('→ $methodName');
    if (params != null && params.isNotEmpty) {
      buffer.write(' | Params: $params');
    }
    _log(LogLevel.debug, buffer.toString(), tag: 'METHOD');
  }

  /// Log method exit (for debugging)
  static void exit(String methodName, {dynamic result}) {
    final buffer = StringBuffer('← $methodName');
    if (result != null) {
      buffer.write(' | Result: $result');
    }
    _log(LogLevel.debug, buffer.toString(), tag: 'METHOD');
  }

  /// Log performance metrics
  static void performance(String operation, Duration duration,
      {Map<String, dynamic>? context}) {
    final buffer =
        StringBuffer('⏱ $operation took ${duration.inMilliseconds}ms');
    if (context != null && context.isNotEmpty) {
      buffer.write(' | Context: $context');
    }
    _log(LogLevel.info, buffer.toString(), tag: 'PERFORMANCE');
  }

  /// Internal logging method
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Skip if level is below current threshold
    if (level.index < _currentLevel.index) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final tagStr = tag != null ? '[$tag] ' : '';
    final fullMessage =
        '$timestamp: $levelStr: ${AppConstants.appTag} $tagStr$message';

    // Console logging
    if (_enableConsoleLogging && kDebugMode) {
      if (level == LogLevel.error) {
        print(fullMessage);
        if (error != null) print('Error: $error');
        if (stackTrace != null) print('StackTrace: $stackTrace');
      } else {
        print(fullMessage);
      }
    }

    // File logging (could be implemented later)
    if (_enableFileLogging) {
      // TODO: Implement file logging if needed
    }
  }

  /// Create a logger with a specific tag
  static Logger withTag(String tag) {
    return Logger(tag);
  }
}

/// Logger with a predefined tag for consistent logging
class Logger {
  final String tag;

  const Logger(this.tag);

  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    Log.d(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void info(String message, {Object? error, StackTrace? stackTrace}) {
    Log.i(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    Log.w(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    Log.e(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void exception(PlanovaException exception, {StackTrace? stackTrace}) {
    Log.exception(exception, tag: tag, stackTrace: stackTrace);
  }

  void entry(String methodName, {Map<String, dynamic>? params}) {
    Log.entry(methodName, params: {'tag': tag, ...?params});
  }

  void exit(String methodName, {dynamic result}) {
    Log.exit(methodName, result: result);
  }

  void performance(String operation, Duration duration,
      {Map<String, dynamic>? context}) {
    Log.performance(operation, duration, context: {'tag': tag, ...?context});
  }
}
