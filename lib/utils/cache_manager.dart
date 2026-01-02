import 'dart:io';
import 'package:planova/utils/logger.dart';

/// Simple caching manager for frequently accessed data
class CacheManager {
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Get cached value if still valid
  static T? getCached<T>(String key) {
    final cached = _cache[key];
    if (cached != null && !cached['expired']) {
      return cached['value'] as T?;
    }
    return null;
  }

  /// Set cached value with timestamp
  static void setCached<T>(String key, T value) {
    _cache[key] = {
      'value': value,
      'timestamp': DateTime.now(),
    };
    Log.d('🗄️ CacheManager: Cached $key');
  }

  /// Clear expired cache entries
  static void cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      final timestamp = entry.value['timestamp'] as DateTime?;
      if (timestamp != null && now.difference(timestamp) > _cacheTimeout) {
        expiredKeys.add(entry.key);
        _cache.remove(entry.key);
      }
    }

    if (expiredKeys.isNotEmpty) {
      Log.d(
          '🗑️ CacheManager: Cleaned ${expiredKeys.length} expired cache entries');
    }
  }
}
