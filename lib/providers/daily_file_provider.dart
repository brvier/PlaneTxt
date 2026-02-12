import 'dart:async';

// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:planova/models/calendar_event.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/providers/event_provider.dart';
import 'package:planova/repositories/daily_repository.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/services/widget_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';
import 'package:provider/provider.dart';

class DailyFileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  late DailyRepository _dailyRepository;

  List<DailyFile> _dailyFiles = [];
  String _selectedDate = '';
  String? _lastWidgetUpdateDate;
  Timer? _widgetUpdateTimer;
  static const Duration _widgetUpdateInterval = Duration(minutes: 30);

  DailyFileProvider() {
    Log.i('🚀 DailyFileProvider: Constructor called');
    _dailyRepository = DailyRepository(_storageService);
  }

  List<DailyFile> get dailyFiles => List.unmodifiable(_dailyFiles);
  String get selectedDate => _selectedDate;

  Future<void> loadDailyFiles({bool forceReload = false}) async {
    Log.i(
        '📅 DailyFileProvider: Loading daily files (forceReload: $forceReload)...');
    try {
      _dailyFiles = await _dailyRepository.loadAll(forceReload: forceReload);
      Log.i('📅 DailyFileProvider: Loaded ${_dailyFiles.length} daily files');

      // Update widget with today's content
      await _updateWidget();

      notifyListeners();
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error loading daily files', error: e);
      rethrow;
    }
  }

  /// Incremental update - only load modified daily files
  Future<void> loadDailyFilesIncremental() async {
    Log.i('📅 DailyFileProvider: Loading incremental daily file changes...');
    try {
      _dailyFiles = await _dailyRepository.loadIncremental();
      Log.i(
          '📅 DailyFileProvider: Incremental load completed, ${_dailyFiles.length} total files');

      // Update widget with today's content
      await _updateWidget();

      notifyListeners();
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error in incremental daily file load',
          error: e);
      rethrow;
    }
  }

  /// Add events from external sources (like ICS files) to appropriate daily files
  Future<void> addEventsFromIntent(
      BuildContext context, List<CalendarEvent> events) async {
    try {
      Log.i('📅 DailyFileProvider: Adding ${events.length} events from intent');

      // Group events by date
      final eventsByDate = <String, List<CalendarEvent>>{};
      for (final event in events) {
        eventsByDate.putIfAbsent(event.date, () => []).add(event);
      }

      // Process each date's events
      for (final entry in eventsByDate.entries) {
        final date = entry.key;
        final dateEvents = entry.value;

        // Get existing daily file or create template
        var dailyFile = await getDailyFile(date);
        String content = dailyFile?.content ?? '';

        // If no content exists, use the default template
        if (content.isEmpty) {
          // We need to get the template from ThemeProvider
          // This is a bit tricky since we can't access ThemeProvider directly here
          // For now, we'll use a basic template
          content = _getBasicDailyTemplate();
        }

        // Add events to content
        content = _addEventsToDailyContent(content, dateEvents);

        // Save the updated content
        await saveDailyFile(context, date, content);
      }

      Log.i('📅 DailyFileProvider: Successfully added events from intent');
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error adding events from intent', error: e);
      rethrow;
    }
  }

  /// Get a basic daily template
  String _getBasicDailyTemplate() {
    return '''# Daily Notes

## Events

## Tasks

## Notes
''';
  }

  /// Add events to daily content
  String _addEventsToDailyContent(String content, List<CalendarEvent> events) {
    // Sort events by time
    events.sort((a, b) => a.time.compareTo(b.time));

    final lines = content.split('\n');
    final newLines = <String>[];

    bool inEventsSection = false;
    bool eventsSectionFound = false;

    for (final line in lines) {
      // Check if we're entering the events section
      if (line.trim().startsWith('## Events') ||
          line.trim().startsWith('## Event')) {
        newLines.add(line);
        inEventsSection = true;
        eventsSectionFound = true;

        // Add all events after the header
        for (final event in events) {
          newLines.add('- @${event.formattedTime} ${event.title}');
          if (event.description.isNotEmpty) {
            // Add description as indented lines
            final descriptionLines = event.description.split('\n');
            for (final descLine in descriptionLines) {
              if (descLine.trim().isNotEmpty) {
                newLines.add('  $descLine');
              }
            }
          }
        }
        continue;
      }

      // If we're in events section and hit a non-event, non-empty line, we're done with events
      if (inEventsSection && line.trim().isNotEmpty && !_isEventLine(line)) {
        inEventsSection = false;
      }

      newLines.add(line);
    }

    // If no events section was found, add one at the end
    if (!eventsSectionFound) {
      newLines.add('## Events');
      newLines.add('');

      for (final event in events) {
        newLines.add('- @${event.formattedTime} ${event.title}');
        if (event.description.isNotEmpty) {
          final descriptionLines = event.description.split('\n');
          for (final descLine in descriptionLines) {
            if (descLine.trim().isNotEmpty) {
              newLines.add('  $descLine');
            }
          }
        }
      }
    }

    return newLines.join('\n');
  }

  /// Check if a line is an event line
  bool _isEventLine(String line) {
    return RegExp(r'^\s*-\s*@\d{1,2}:\d{2}').hasMatch(line.trim());
  }

  Future<void> saveDailyFile(
      BuildContext context, String date, String content) async {
    try {
      Log.d('📅 DailyFileProvider: Saving daily file for $date');
      final dailyFile = await _dailyRepository.create(date, content);

      // Update local list
      final index = _dailyFiles.indexWhere((d) => d.date == date);
      if (index != -1) {
        _dailyFiles[index] = dailyFile;
      } else {
        _dailyFiles.add(dailyFile);
        _dailyFiles.sort((a, b) => b.date.compareTo(a.date));
      }

      // Update widget with today's content
      await _updateWidget();

      // Schedule event notifications (only if context is still valid)
      try {
        final eventProvider =
            Provider.of<EventProvider>(context, listen: false);
        await eventProvider.scheduleEventNotifications(date, content);
      } catch (e) {
        // Context might be disposed, log but don't fail
        Log.w(
            '⚠️  DailyFileProvider: Could not access EventProvider, context may be disposed',
            error: e);
      }

      Log.d('📅 DailyFileProvider: Saved daily file for $date');
      notifyListeners();
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error saving daily file', error: e);
      rethrow;
    }
  }

  void setSelectedDate(String date) {
    _selectedDate = date;
    Log.d('📅 DailyFileProvider: Selected date set to $date');
    notifyListeners();
  }

  /// Get daily file from memory cache only (fast, may be stale)
  DailyFile? getDailyFileFromCache(String date) {
    try {
      return _dailyFiles.firstWhere((d) => d.date == date);
    } catch (e) {
      Log.d('📅 DailyFileProvider: No daily file in cache for $date');
      return null;
    }
  }

  /// Get daily file, always checking disk for latest version
  /// Use this when you need to ensure you have the most recent data
  Future<DailyFile?> getDailyFile(String date) async {
    // Always check disk to get the latest version
    // File could have been edited by another application
    final fromDisk = await _dailyRepository.loadByDate(date);

    if (fromDisk != null) {
      // Update in-memory cache
      final index = _dailyFiles.indexWhere((d) => d.date == date);
      if (index != -1) {
        _dailyFiles[index] = fromDisk;
      } else {
        _dailyFiles.add(fromDisk);
        _dailyFiles.sort((a, b) => b.date.compareTo(a.date));
      }
      Log.d('📅 DailyFileProvider: Loaded daily file for $date from disk');
      return fromDisk;
    }

    // File doesn't exist on disk
    return null;
  }

  /// Alias for getDailyFile - loads from disk
  Future<DailyFile?> ensureDailyFileLoaded(String date) async {
    return getDailyFile(date);
  }

  String getTodayDate() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    Log.d('📅 DailyFileProvider: Today\'s date is $date');
    return date;
  }

  bool hasUndoneTodos(String date) {
    final dailyFile = getDailyFileFromCache(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    final hasUndone = tasks.any((task) => !task.isCompleted);
    Log.d('📅 DailyFileProvider: Date $date has undone todos: $hasUndone');
    return hasUndone;
  }

  bool hasTodos(String date) {
    final dailyFile = getDailyFileFromCache(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    final hasTodos = tasks.isNotEmpty;
    Log.d('📅 DailyFileProvider: Date $date has todos: $hasTodos');
    return hasTodos;
  }

  int getUndoneTodoCount(String date) {
    final dailyFile = getDailyFileFromCache(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return 0;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    final count = tasks.where((task) => !task.isCompleted).length;
    Log.d('📅 DailyFileProvider: Date $date has $count undone todos');
    return count;
  }

  List<CalendarEvent> getCalendarEvents(String date) {
    final dailyFile = getDailyFileFromCache(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return [];

    final events = MarkdownParser.parseEvents(date, dailyFile.content);
    events.sort((a, b) => a.time.compareTo(b.time));
    Log.d('📅 DailyFileProvider: Found ${events.length} events for $date');
    return events;
  }

  bool hasCalendarEvents(String date) {
    final hasEvents = getCalendarEvents(date).isNotEmpty;
    Log.d('📅 DailyFileProvider: Date $date has events: $hasEvents');
    return hasEvents;
  }

  Future<void> checkDateChangeAndUpdateWidget() async {
    final todayDate = getTodayDate();
    if (_lastWidgetUpdateDate != todayDate) {
      Log.i(
          '📱 DailyFileProvider: Date changed detected (was: $_lastWidgetUpdateDate, now: $todayDate), updating widget');
      await _updateWidget();
    }
  }

  /// Update widget with today's daily file
  Future<void> _updateWidget() async {
    try {
      if (_storageService.orgDirectory == null) {
        Log.d(
            '📱 DailyFileProvider: Skipping widget update - directories not initialized');
        return;
      }

      final todayDate = getTodayDate();

      if (_lastWidgetUpdateDate != todayDate) {
        Log.i(
            '📱 DailyFileProvider: Date changed from $_lastWidgetUpdateDate to $todayDate, updating widget');
        _lastWidgetUpdateDate = todayDate;
      } else {
        Log.d(
            '📱 DailyFileProvider: Updating widget (date unchanged: $todayDate)');
      }

      final todayDailyFile = await getDailyFile(todayDate);

      if (todayDailyFile != null) {
        Log.d('📱 DailyFileProvider: Updating widget with daily file content');
        await WidgetService.updateWithDailyFile(todayDailyFile);
      }

      Log.i('📱 DailyFileProvider: Widget updated successfully');
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error updating widget', error: e);
    }
  }

  void startWidgetUpdateTimer() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = Timer.periodic(_widgetUpdateInterval, (timer) async {
      Log.d('📱 DailyFileProvider: Periodic widget update triggered');
      try {
        await loadDailyFiles();
        Log.d('📱 DailyFileProvider: Periodic widget update completed');
      } catch (e) {
        Log.e('❌ DailyFileProvider: Error in periodic widget update', error: e);
      }
    });
    Log.i(
        '📱 DailyFileProvider: Started periodic widget update timer (every 30 minutes)');
  }

  @override
  void dispose() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = null;
    Log.i('📅 DailyFileProvider: Disposed');
    super.dispose();
  }
}
