import 'package:shared_preferences/shared_preferences.dart';

/// Singleton wrapper around SharedPreferences to avoid repeated getInstance() calls.
class SharedPrefsService {
  static SharedPreferences? _instance;

  /// Must be called once before runApp (in main.dart).
  static Future<void> initialize() async {
    _instance = await SharedPreferences.getInstance();
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
