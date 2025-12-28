# Planova Agent Development Guide

This file provides comprehensive guidance for agentic coding agents working on the Planova Flutter project.

## Project Overview

Planova is a Flutter-based personal productivity app that manages todos, agenda, journal, and notes using structured Markdown files. The app follows a clean architecture pattern with Provider state management and supports cross-platform deployment (Android, iOS, Web, Desktop).

## Development Commands

### Dependencies & Setup
```bash
flutter pub get                    # Install dependencies
flutter clean                     # Clean build cache
flutter pub deps                   # Show dependency tree
```

### Code Quality & Analysis
```bash
flutter analyze                   # Run static analysis (uses flutter_lints)
flutter format .                  # Format all Dart files
dart fix --apply                  # Apply automated fixes
```

### Testing
```bash
flutter test                      # Run all tests
flutter test test/widget_test.dart              # Run single test file
flutter test --name "test_name"                 # Run tests by name pattern
flutter test --coverage              # Run tests with coverage
flutter test --reporter=expanded     # Verbose test output
```

### Building & Running
```bash
flutter run                      # Run in debug mode
flutter run --release           # Run in release mode
flutter build apk              # Build Android APK
flutter build ios              # Build iOS app
flutter build web              # Build for web
flutter build windows          # Build for Windows
flutter build macos            # Build for macOS
flutter build linux            # Build for Linux
```

## Code Style Guidelines

### Import Organization
Organize imports in this specific order:
1. Third-party packages (alphabetical)
2. Flutter SDK packages (alphabetical)
3. Local project imports (alphabetical)

```dart
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planova/constants/app_constants.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/providers/daily_file_provider.dart';
import 'package:planova/utils/logger.dart';
```

### Naming Conventions
- **Classes/Enums**: PascalCase (`DailyFile`, `CalendarEvent`, `LogLevel`)
- **Variables/Methods**: camelCase (`selectedDate`, `loadDailyFiles()`)
- **Files/Directories**: snake_case (`daily_file.dart`, `utils/logger.dart`)
- **Constants**: `static const` with descriptive names (`widgetUpdateInterval`)
- **Private members**: Prefix with underscore (`_dailyFiles`, `_loadData()`)

### File & Directory Structure
```
lib/
├── constants/          # App-wide constants and messages
├── models/            # Data models and entities
├── providers/         # State management (Provider pattern)
├── repositories/      # Data access layer
├── screens/           # UI screens/pages
├── services/          # Business logic and external services
├── themes/            # App theming and colors
├── utils/             # Utility classes and helpers
├── widgets/           # Reusable UI components
└── main.dart          # App entry point
```

### Error Handling
Use the custom exception hierarchy for consistent error handling:

```dart
// Create specific exceptions
throw FileOperationException(
  'Failed to save daily file',
  filePath: filePath,
  details: 'Permission denied or file locked',
  originalError: e,
);

// Handle exceptions gracefully
try {
  await _saveDailyFile(content);
} catch (e) {
  Log.e('Save operation failed', error: e);
  rethrow; // Re-throw to let caller handle
}
```

### Logging Guidelines
Use structured logging with the Log class:

```dart
// Basic logging
Log.d('Debug message');                    // Debug
Log.i('Info message');                     // Info  
Log.w('Warning message');                  // Warning
Log.e('Error message', error: e);          // Error

// Method tracing
Log.entry('methodName', params: {'id': id});
Log.exit('methodName', result: result);

// Performance logging
Log.performance('databaseQuery', duration);

// Exception logging
Log.exception(customException);

// With context and emojis (following existing pattern)
Log.i('📅 DailyFileProvider: Loading daily files...');
Log.e('❌ StorageService: Failed to initialize', error: e);
```

### State Management
Follow Provider pattern conventions:

```dart
class DailyFileProvider extends ChangeNotifier {
  // Private fields
  List<DailyFile> _dailyFiles = [];
  String _selectedDate = '';
  
  // Public getters (immutable)
  List<DailyFile> get dailyFiles => List.unmodifiable(_dailyFiles);
  String get selectedDate => _selectedDate;
  
  // Public methods with proper error handling
  Future<void> loadDailyFiles() async {
    try {
      _dailyFiles = await _repository.loadAll();
      notifyListeners();
    } catch (e) {
      Log.e('Failed to load daily files', error: e);
      rethrow;
    }
  }
  
  // Proper disposal
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

### Model Classes
Create immutable models with proper copyWith methods:

```dart
class DailyFile {
  final String path;
  final String date;
  final String content;

  const DailyFile({
    required this.path,
    required this.date,
    required this.content,
  });

  DailyFile copyWith({
    String? path,
    String? date,
    String? content,
  }) {
    return DailyFile(
      path: path ?? this.path,
      date: date ?? this.date,
      content: content ?? this.content,
    );
  }

  // Computed properties with getters
  DateTime get dateTime => _parseDate(date);
  String get formattedDate => _formatDate(date);
}
```

### Testing Patterns
Follow established testing conventions:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planova/services/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetService', () {
    test('should update widget with daily file', () async {
      // Arrange
      final dailyFile = DailyFile(/* ... */);
      
      // Act
      await WidgetService.updateWithDailyFile(dailyFile);
      
      // Assert
      expect(find.byType(/* ... */), findsOneWidget);
    });
  });
}
```

## Key Constants & Patterns

### File Structure Constants
- File extension: `.md` for Markdown files
- Date format: `yyyyMMdd` (e.g., `20241228`)
- Directory names from `AppConstants`: `orgDirName`, `dailiesDirName`, `notesDirName`

### SharedPreferences Keys
- Use keys from `AppConstants` class
- Don't prefix with `flutter.` (handled automatically)
- Examples: `themeModeKey`, `storagePathKey`, `widgetThemeKey`

### Default Templates
- Use `AppConstants.defaultDailyTemplate` for new daily files
- Follow existing Markdown structure with `##` headers

## Development Workflow

1. **Before committing**: Always run `flutter analyze` and fix any issues
2. **New features**: Write tests before or alongside implementation
3. **Code review**: Ensure import order, naming conventions, and error handling
4. **Performance**: Use Log.performance() for tracking operation times
5. **Consistency**: Follow existing patterns and use centralized constants

## Platform-Specific Considerations

- **Android**: Handle permissions properly, check directory access
- **iOS**: Follow Apple design guidelines for UI components
- **Web**: Ensure responsive design and proper file handling
- **Desktop**: Consider window management and platform-specific shortcuts

Remember: This codebase emphasizes structured logging, proper error handling, and clean architecture patterns. Always prioritize maintainability and consistency when making changes.