import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planova/models/calendar_event.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/repositories/daily_repository.dart';
import 'package:planova/services/file_monitor_service.dart';
import 'package:planova/services/notification_service.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/services/widget_service.dart';
import 'package:planova/utils/daily_content_helper.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';

/// Cached parse result for one daily file. The [contentHash] is used to
/// detect when [content] has changed and invalidate.
class _ParsedDaily {
  final int contentHash;
  final List<TaskItem> tasks;
  final List<CalendarEvent> events; // sorted by time
  final List<String> notes;
  _ParsedDaily(this.contentHash, this.tasks, this.events, this.notes);
}

class DailyFileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  late DailyRepository _dailyRepository;

  List<DailyFile> _dailyFiles = [];
  // Index of the same files keyed by date for O(1) lookup.
  final Map<String, DailyFile> _byDate = {};
  // Memoised task/event parsing per date — invalidated by content hash.
  final Map<String, _ParsedDaily> _parseCache = {};
  String _selectedDate = '';
  String? _lastWidgetUpdateDate;
  Timer? _widgetUpdateTimer;
  static const Duration _widgetUpdateInterval = Duration(minutes: 30);

  // Debounce for post-save side work (notifications + home-screen widget):
  // autosave fires every 500ms while typing, but rescheduling notifications
  // and pushing the widget only needs to happen once the burst settles.
  final Map<String, Timer> _postSaveTimers = {};
  static const Duration _postSaveDebounce = Duration(seconds: 2);

  DailyFileProvider() {
    Log.i('🚀 DailyFileProvider: Constructor called');
    _dailyRepository = DailyRepository(_storageService);
    FileMonitorService().onDailyFileChanged = _onExternalFileChanged;
  }

  List<DailyFile> get dailyFiles => List.unmodifiable(_dailyFiles);
  String get selectedDate => _selectedDate;

  // -- internal index/cache management ---------------------------------------

  void _replaceAllFiles(List<DailyFile> files) {
    _dailyFiles = files;
    _byDate
      ..clear()
      ..addEntries(files.map((f) => MapEntry(f.date, f)));
    // Drop cache entries for dates that no longer exist; keep the rest —
    // their hash check will detect any content changes.
    _parseCache.removeWhere((date, _) => !_byDate.containsKey(date));
  }

  void _upsertFile(DailyFile file) {
    final existing = _byDate[file.date];
    if (existing == null) {
      _dailyFiles = [..._dailyFiles, file]
        ..sort((a, b) => b.date.compareTo(a.date));
    } else {
      final idx = _dailyFiles.indexOf(existing);
      if (idx != -1) {
        _dailyFiles[idx] = file;
      } else {
        _dailyFiles = [..._dailyFiles, file]
          ..sort((a, b) => b.date.compareTo(a.date));
      }
    }
    _byDate[file.date] = file;
    _parseCache.remove(file.date);
  }

  _ParsedDaily? _getParsed(String date) {
    final file = _byDate[date];
    if (file == null || file.content.isEmpty) return null;
    final hash = file.content.hashCode;
    final cached = _parseCache[date];
    if (cached != null && cached.contentHash == hash) return cached;
    final tasks = MarkdownParser.parseTasks(file.content);
    final events = MarkdownParser.parseEvents(date, file.content)
      ..sort((a, b) => a.time.compareTo(b.time));
    final notes = MarkdownParser.parseNotes(file.content);
    final parsed = _ParsedDaily(hash, tasks, events, notes);
    _parseCache[date] = parsed;
    return parsed;
  }

  /// Re-read one date from disk after an external change and update the UI.
  void _onExternalFileChanged(String date) {
    unawaited(() async {
      try {
        final fromDisk = await _dailyRepository.loadByDate(date);
        final existing = _byDate[date];
        if (fromDisk != null) {
          if (existing == null || existing.content != fromDisk.content) {
            Log.i(
                '📅 DailyFileProvider: External change detected for $date, refreshing');
            _upsertFile(fromDisk);
            notifyListeners();
          }
        } else if (existing != null) {
          Log.i(
              '📅 DailyFileProvider: Daily file for $date deleted externally');
          _byDate.remove(date);
          _parseCache.remove(date);
          _dailyFiles = _dailyFiles.where((f) => f.date != date).toList();
          notifyListeners();
        }
      } catch (e) {
        Log.e('❌ DailyFileProvider: Error refreshing $date after change',
            error: e);
      }
    }());
  }

  Future<void> loadDailyFiles({bool forceReload = false}) async {
    Log.i(
        '📅 DailyFileProvider: Loading daily files (forceReload: $forceReload)...');
    try {
      _replaceAllFiles(
          await _dailyRepository.loadAll(forceReload: forceReload));
      Log.i('📅 DailyFileProvider: Loaded ${_dailyFiles.length} daily files');

      // Notify the UI first; the home-screen widget can follow.
      notifyListeners();
      unawaited(_updateWidget());
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error loading daily files', error: e);
      rethrow;
    }
  }

  /// Fast startup load: restore last-known content from disk cache and
  /// refresh today's file from disk, notifying listeners after each step.
  /// Does NOT do a full mtime sweep — call [loadDailyFiles] in the
  /// background afterwards to validate the rest of the history.
  Future<void> loadTodayPriority() async {
    Log.i('📅 DailyFileProvider: Priority-loading today...');
    try {
      // Stage A: in-memory list from disk cache (instant).
      final cached = await _dailyRepository.restoreFromDiskCache();
      if (cached.isNotEmpty) {
        _replaceAllFiles(cached);
        Log.i(
            '📅 DailyFileProvider: Restored ${cached.length} daily files from disk cache');
        notifyListeners();
      }

      // Stage B: refresh today from disk so it's never stale.
      final todayDate = getTodayDate();
      final todayFile = await _dailyRepository.loadByDate(todayDate);
      if (todayFile != null) {
        _upsertFile(todayFile);
      }

      // Notify the UI first; the home-screen widget update (disk read +
      // platform channel) must not delay first paint.
      notifyListeners();
      unawaited(_updateWidget());
      Log.i('📅 DailyFileProvider: Today-priority load complete');
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error in today-priority load', error: e);
      rethrow;
    }
  }

  /// Incremental update - only load modified daily files
  Future<void> loadDailyFilesIncremental() async {
    Log.i('📅 DailyFileProvider: Loading incremental daily file changes...');
    try {
      _replaceAllFiles(await _dailyRepository.loadIncremental());
      Log.i(
          '📅 DailyFileProvider: Incremental load completed, ${_dailyFiles.length} total files');

      notifyListeners();
      unawaited(_updateWidget());
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
        if (!context.mounted) return;
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

  /// Add events to daily content via the shared content helper.
  /// Each event becomes one logical line `- @HH:MM Title` followed by
  /// indented description lines.
  String _addEventsToDailyContent(String content, List<CalendarEvent> events) {
    final eventLines = events.map((e) {
      final desc = e.description
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => '  $l')
          .join('\n');
      final headerLine = '- @${e.formattedTime} ${e.title}';
      return desc.isEmpty ? headerLine : '$headerLine\n$desc';
    }).toList();

    return DailyContentHelper.insertEventsChronologically(
      content,
      eventLines,
      r'^#{1,2}\s+.*Events?',
    );
  }

  Future<void> saveDailyFile(
      BuildContext context, String date, String content) async {
    try {
      Log.d('📅 DailyFileProvider: Saving daily file for $date');
      final dailyFile = await _dailyRepository.create(date, content);

      _upsertFile(dailyFile);

      // Tell FileMonitorService to skip this date (avoid cancel+reschedule race)
      FileMonitorService().markRecentlyScheduled(date);

      // Notifications + widget update are debounced: while the user types
      // (autosave every 500ms) only the last save of the burst triggers them.
      _postSaveTimers[date]?.cancel();
      _postSaveTimers[date] = Timer(_postSaveDebounce, () {
        _postSaveTimers.remove(date);
        unawaited(_scheduleEventNotifications(date, content));
        unawaited(_updateWidget());
        // Flush the disk cache: the startup fast path restores from it, and
        // on Android the process is often killed before the next full scan.
        unawaited(_dailyRepository.persistCache());
      });

      Log.d('📅 DailyFileProvider: Saved daily file for $date');
      notifyListeners();
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error saving daily file', error: e);
      rethrow;
    }
  }

  Future<void> _scheduleEventNotifications(String date, String content) async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final events = MarkdownParser.parseEvents(date, content);

      await notificationService.cancelNotificationsForDate(date);

      for (final event in events) {
        final eventId =
            NotificationService.generateEventId(event.displayTitle, event.time);
        await notificationService.scheduleEventNotification(
          id: eventId,
          title: event.displayTitle,
          description: event.description,
          eventDateTime: event.time,
          date: date,
        );
      }

      Log.i(
          '📅 DailyFileProvider: Scheduled ${events.length} event notifications for $date');
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error scheduling event notifications',
          error: e);
    }
  }

  void setSelectedDate(String date) {
    _selectedDate = date;
    Log.d('📅 DailyFileProvider: Selected date set to $date');
    notifyListeners();
  }

  /// Get daily file from memory cache only (fast, may be stale)
  DailyFile? getDailyFileFromCache(String date) => _byDate[date];

  /// Persist the repository disk cache now (e.g. when the app is paused).
  Future<void> persistCache() => _dailyRepository.persistCache();

  /// Get daily file, always checking disk for latest version
  /// Use this when you need to ensure you have the most recent data
  Future<DailyFile?> getDailyFile(String date) async {
    final fromDisk = await _dailyRepository.loadByDate(date);
    if (fromDisk != null) {
      final existing = _byDate[date];
      final changed = existing == null || existing.content != fromDisk.content;
      _upsertFile(fromDisk);
      if (changed) {
        Log.d('📅 DailyFileProvider: Loaded daily file for $date from disk');
        notifyListeners();
      }
      return fromDisk;
    }
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

  bool hasUndoneTodos(String date) =>
      _getParsed(date)?.tasks.any((t) => !t.isCompleted) ?? false;

  bool hasTodos(String date) => _getParsed(date)?.tasks.isNotEmpty ?? false;

  int getUndoneTodoCount(String date) =>
      _getParsed(date)?.tasks.where((t) => !t.isCompleted).length ?? 0;

  /// Memoised tasks for a date — cheap to call from build methods.
  List<TaskItem> getTasks(String date) => _getParsed(date)?.tasks ?? const [];

  /// Memoised free-text notes for a date — cheap to call from build methods.
  List<String> getNotes(String date) => _getParsed(date)?.notes ?? const [];

  List<CalendarEvent> getCalendarEvents(String date) =>
      _getParsed(date)?.events ?? const [];

  bool hasCalendarEvents(String date) =>
      _getParsed(date)?.events.isNotEmpty ?? false;

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

      if (todayDailyFile != null && todayDailyFile.content.isNotEmpty) {
        await WidgetService.updateWithDailyFile(todayDailyFile);
      } else {
        await WidgetService.updateWidgetEmptyDay(todayDate);
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
        // Incremental: only re-reads files whose mtime changed, and skips
        // the disk-cache rewrite when nothing did.
        await loadDailyFilesIncremental();
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
    for (final timer in _postSaveTimers.values) {
      timer.cancel();
    }
    _postSaveTimers.clear();
    if (FileMonitorService().onDailyFileChanged == _onExternalFileChanged) {
      FileMonitorService().onDailyFileChanged = null;
    }
    Log.i('📅 DailyFileProvider: Disposed');
    super.dispose();
  }
}
