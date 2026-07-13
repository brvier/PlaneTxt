/// Application-wide constants
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // Widget update intervals
  static const Duration widgetUpdateInterval = Duration(minutes: 30);
  static const Duration initializationTimeout = Duration(seconds: 5);
  static const Duration debounceDelay = Duration(milliseconds: 500);

  // File operations
  static const String markdownExtension = '.md';
  static const String testFileName = '.test_write';
  static const int maxInitializationAttempts = 50;
  static const Duration initializationAttemptDelay =
      Duration(milliseconds: 100);

  // Date formatting
  static const int dateFormatLength = 8;
  static const int yearStart = 0;
  static const int yearEnd = 4;
  static const int monthStart = 4;
  static const int monthEnd = 6;
  static const int dayStart = 6;
  static const int dayEnd = 8;

  // Directory names
  static const String orgDirName = 'Org';
  static const String dailiesDirName = 'dailies';
  static const String archivesDirName = 'archives';
  static const String notesDirName = 'notes';

  // Default template
  static const String defaultDailyTemplate = '''# 📅 Events

# ✅ Todos

# 📝 Logs

# 🗒️ Notes
''';

  // Default regex patterns
  static const String defaultTodoHeaderRegex = r'^#{1,2}\s+.*(Todos?|Tasks?)';
  static const String defaultEventHeaderRegex = r'^#{1,2}\s+.*Events?';
  static const String defaultLogHeaderRegex = r'^#{1,2}\s+.*(Journal|Logs?)';

  // SharedPreferences keys
  static const String themeModeKey = 'theme_mode';
  static const String appThemeKey = 'app_theme';
  static const String storagePathKey = 'storage_path';
  // SAF document-tree URI of the user-selected storage folder (Android).
  static const String storageTreeUriKey = 'storage_tree_uri';
  // Human-readable name of that folder, for display.
  static const String storageTreeNameKey = 'storage_tree_name';
  static const String templateKey = 'daily_template';
  // NOTE: Do not prefix these with `flutter.`.
  // The `shared_preferences` Android implementation already prefixes keys with
  // `flutter.` under the hood; adding it here would result in `flutter.flutter.*`
  // and the native widget (Android) won’t find the values.
  static const String widgetThemeKey = 'widget_dark_theme';
  static const String widgetTransparencyKey = 'widget_transparency';
  static const String widgetBackgroundColorKey = 'widget_background_color';
  static const String widgetTitleColorKey = 'widget_title_color';
  static const String widgetTextColorKey = 'widget_text_color';
  static const String todoHeaderRegexKey = 'todo_header_regex';
  static const String eventHeaderRegexKey = 'event_header_regex';

  // Widget data keys
  static const String widgetDailyContentKey = 'widget_daily_content';
  static const String widgetDateKey = 'widget_date';

  // Logging
  static const String appTag = 'Planova';
}

/// Error messages
class ErrorMessages {
  // Private constructor to prevent instantiation
  ErrorMessages._();

  static const String initializationFailed = 'Failed to initialize application';
  static const String directoryNotFound = 'Directory not found';
  static const String fileNotFound = 'File not found';
  static const String permissionDenied = 'Permission denied';
  static const String invalidPath = 'Invalid file path';
  static const String storageError = 'Storage operation failed';
  static const String networkError = 'Network operation failed';
  static const String parseError = 'Failed to parse content';
  static const String unknownError = 'An unknown error occurred';
}

/// Success messages
class SuccessMessages {
  // Private constructor to prevent instantiation
  SuccessMessages._();

  static const String fileSaved = 'File saved successfully';
  static const String directoryCreated = 'Directory created successfully';
  static const String settingsSaved = 'Settings saved successfully';
  static const String permissionsGranted = 'Permissions granted successfully';
}
