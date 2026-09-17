import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton wrapper around SharedPreferences to avoid repeated getInstance() calls.
class SharedPrefsService {
  static SharedPreferences? _instance;

  /// Must be called once before runApp (in main.dart).
  static Future<void> initialize() async {
    await _migrateLegacyLinuxPrefs();
    _instance = await SharedPreferences.getInstance();
  }

  /// The app was renamed from Planova to PlaneTxt, which moved the Linux
  /// application id (and so the preferences directory) from
  /// fr.rvier.planova to fr.rvier.planetxt. Copy the old preferences once.
  static Future<void> _migrateLegacyLinuxPrefs() async {
    if (!Platform.isLinux) return;
    try {
      final env = Platform.environment;
      final dataHome = env['XDG_DATA_HOME']?.isNotEmpty == true
          ? env['XDG_DATA_HOME']!
          : p.join(env['HOME'] ?? '', '.local', 'share');
      final legacy =
          File(p.join(dataHome, 'fr.rvier.planova', 'shared_preferences.json'));
      final current =
          File(p.join(dataHome, 'fr.rvier.planetxt', 'shared_preferences.json'));
      if (await current.exists() || !await legacy.exists()) return;
      await current.parent.create(recursive: true);
      await legacy.copy(current.path);
    } catch (_) {
      // Best effort: starting with default preferences is acceptable.
    }
  }

  /// Returns the cached SharedPreferences instance.
  /// Throws if [initialize] was not called first.
  static SharedPreferences get instance {
    final prefs = _instance;
    if (prefs == null) {
      throw StateError(
          'SharedPrefsService.initialize() must be called before accessing instance');
    }
    return prefs;
  }
}
