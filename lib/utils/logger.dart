import 'package:flutter/foundation.dart';

class Log {
  static void d(String message) {
    if (kDebugMode) {
      print('DEBUG: $message');
    }
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('ERROR: $message');
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
    }
  }

  static void i(String message) {
    if (kDebugMode) {
      print('INFO: $message');
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      print('WARN: $message');
    }
  }
}
