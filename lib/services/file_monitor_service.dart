import 'dart:async';

import 'package:planova/models/daily_file.dart';
import 'package:planova/services/notification_service.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';

class FileMonitorService {
  static final FileMonitorService _instance = FileMonitorService._internal();
  factory FileMonitorService() => _instance;
  FileMonitorService._internal();

  final StorageService _storageService = StorageService();
  Timer? _pollingTimer;
  StreamSubscription<void>? _watchSubscription;
  Timer? _watchDebounceTimer;
  final Map<String, DateTime> _lastModified = {};
  final NotificationService _notificationService = NotificationService();
  // Polling interval when native file watching isn't available (SAF trees,
  // exotic filesystems).
  static const Duration _pollingInterval = Duration(seconds: 30);
  static const Duration _watchDebounce = Duration(seconds: 2);

  static final _datePattern = RegExp(r'(\d{8})\.md$');

  // Track dates recently scheduled by DailyFileProvider to avoid
  // the FileMonitorService cancelling those notifications immediately.
  final Map<String, DateTime> _recentlyScheduledDates = {};
  static const Duration _debounceWindow = Duration(seconds: 10);

  /// Called whenever a daily file changes (or is deleted) on disk, so the
  /// provider can refresh its in-memory copy - external edits must reach
  /// the UI, not only the notification scheduler.
  void Function(String date)? onDailyFileChanged;

  Future<void> initialize() async {
    final store = _storageService.store;
    if (store == null) {
      Log.e('📁 FileMonitorService: Storage not initialized');
      return;
    }

    await _notificationService.initialize();

    Log.i(
        '📁 FileMonitorService: Starting file monitoring for ${store.rootDescription}');

    // Prefer native file-system events (inotify & co) over polling; fall
    // back to a slow poll where watching isn't supported (SAF trees).
    // Notification scheduling for existing events is deferred - call
    // [scheduleExistingEvents] from the caller once daily files are loaded.
    if (!_startWatching()) {
      _startPolling();
    }
  }

  /// Re-attach watching/polling after the storage root changed.
  Future<void> reinitialize() async {
    _pollingTimer?.cancel();
    _watchDebounceTimer?.cancel();
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    _lastModified.clear();
    await initialize();
  }

  /// Returns true if native watching could be set up.
  bool _startWatching() {
    final store = _storageService.store;
    if (store == null || !store.supportsNativeWatch) return false;
    try {
      final stream = store.watchDirectory(StorageService.dailiesDirName);
      if (stream == null) return false;
      _watchSubscription?.cancel();
      _watchSubscription = stream.listen(
        (event) {
          // Coalesce bursts of events (editors write several times).
          _watchDebounceTimer?.cancel();
          _watchDebounceTimer = Timer(_watchDebounce, _checkForFileChanges);
        },
        onError: (Object e) {
          Log.w('📁 FileMonitorService: Watch failed, falling back to polling',
              error: e);
          _watchSubscription?.cancel();
          _watchSubscription = null;
          _startPolling();
        },
      );
      Log.i('📁 FileMonitorService: Using native file-system watching');
      return true;
    } catch (e) {
      Log.w(
          '📁 FileMonitorService: Could not start watching, using polling',
          error: e);
      return false;
    }
  }

  /// Today as a yyyyMMdd string - daily dates compare correctly as strings.
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  /// Schedule notifications for events that already exist on disk.
  /// Pass [dailyFiles] to reuse already-loaded content and avoid a second
  /// filesystem-wide scan + read; otherwise the directory is scanned.
  /// Only today and future dates are considered - past events can never
  /// produce a notification.
  Future<void> scheduleExistingEvents({
    Iterable<DailyFile>? dailyFiles,
  }) async {
    if (dailyFiles != null) {
      await _scheduleExistingEventsFromFiles(dailyFiles);
    } else {
      await _scheduleExistingEvents();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      _checkForFileChanges();
    });
  }

  Future<void> _checkForFileChanges() async {
    final store = _storageService.store;
    if (store == null) return;

    try {
      final entries = await store.list(StorageService.dailiesDirName);

      // Track which dates still have files
      final existingDates = <String>{};
      final today = _todayString();

      for (final entry in entries) {
        final dateMatch = _datePattern.firstMatch(entry.relPath);
        if (dateMatch == null) continue;

        final date = dateMatch.group(1)!;
        existingDates.add(date);
        final lastModified = entry.modified;
        if (lastModified == null) continue;

        final previous = _lastModified[date];
        if (previous == null || previous.isBefore(lastModified)) {
          _lastModified[date] = lastModified;
          if (date.compareTo(today) < 0) {
            // Past dates can't produce notifications, but a mtime bump on
            // an already-tracked file is an external edit the UI must see.
            // (First sighting is just bookkeeping.)
            if (previous != null) onDailyFileChanged?.call(date);
            continue;
          }
          await _handleFileChange(date, entry.relPath);
        }
      }

      // Remove lastModified entries for dates that no longer have files
      final datesToRemove = _lastModified.keys
          .where((date) => !existingDates.contains(date))
          .toList();
      for (final date in datesToRemove) {
        _lastModified.remove(date);
        onDailyFileChanged?.call(date);
        // Cancel notifications for deleted files
        await _notificationService.cancelNotificationsForDate(date);
        Log.i(
            '🗑️  FileMonitorService: Cancelled notifications for deleted date file: $date');
      }
    } catch (e) {
      Log.e('❌ FileMonitorService: Error checking for file changes', error: e);
    }
  }

  /// Mark a date as recently scheduled by DailyFileProvider so that
  /// the FileMonitorService won't immediately cancel and re-schedule.
  void markRecentlyScheduled(String date) {
    _recentlyScheduledDates[date] = DateTime.now();
  }

  Future<void> _handleFileChange(String date, String relPath) async {
    try {
      // Let the provider refresh its in-memory copy regardless of the
      // notification debounce - for its own writes this is a cheap no-op.
      onDailyFileChanged?.call(date);

      // Skip if DailyFileProvider just scheduled notifications for this date
      final recentTime = _recentlyScheduledDates[date];
      if (recentTime != null &&
          DateTime.now().difference(recentTime) < _debounceWindow) {
        Log.d(
            '📁 FileMonitorService: Skipping $date - recently scheduled by DailyFileProvider');
        return;
      }
      _recentlyScheduledDates.remove(date);

      Log.i('📁 FileMonitorService: File changed - $date');

      final content = await _storageService.store?.read(relPath);
      if (content == null) {
        Log.w('📁 FileMonitorService: File no longer exists - $date');
        return;
      }

      await _scheduleNotificationsForDate(date, content);
    } catch (e) {
      Log.e('❌ FileMonitorService: Error handling file change', error: e);
    }
  }

  Future<void> _scheduleExistingEvents() async {
    final store = _storageService.store;
    if (store == null) return;

    try {
      Log.i(
          '📁 FileMonitorService: Scheduling notifications for existing events...');

      // Review existing notifications first to remove invalid ones
      await _notificationService.reviewNotifications();

      final entries = await store.list(StorageService.dailiesDirName);

      final today = _todayString();
      int scheduledCount = 0;
      for (final entry in entries) {
        final dateMatch = _datePattern.firstMatch(entry.relPath);
        if (dateMatch == null) continue;

        final date = dateMatch.group(1)!;
        if (date.compareTo(today) < 0) continue;
        final content = await store.read(entry.relPath) ?? '';

        if (content.isNotEmpty) {
          await _scheduleNotificationsForDate(date, content);
          scheduledCount++;
        }
      }

      Log.i(
          '📁 FileMonitorService: Scheduled notifications for $scheduledCount files');
    } catch (e) {
      Log.e('❌ FileMonitorService: Error scheduling existing events', error: e);
    }
  }

  Future<void> _scheduleExistingEventsFromFiles(
      Iterable<DailyFile> dailyFiles) async {
    final store = _storageService.store;
    if (store == null) return;

    try {
      Log.i(
          '📁 FileMonitorService: Scheduling notifications from ${dailyFiles.length} cached daily files...');

      // Review existing notifications first to remove invalid ones
      await _notificationService.reviewNotifications();

      final today = _todayString();
      int scheduledCount = 0;
      for (final dailyFile in dailyFiles) {
        if (dailyFile.date.compareTo(today) < 0) continue;
        if (dailyFile.content.isEmpty) continue;

        // Track mtime so the change monitor won't think this file is "new".
        try {
          final mtime = await store.modified(dailyFile.path);
          if (mtime != null) _lastModified[dailyFile.date] = mtime;
        } catch (_) {}

        await _scheduleNotificationsForDate(dailyFile.date, dailyFile.content);
        scheduledCount++;
      }

      Log.i(
          '📁 FileMonitorService: Scheduled notifications for $scheduledCount files (from cache)');
    } catch (e) {
      Log.e('❌ FileMonitorService: Error scheduling existing events from cache',
          error: e);
    }
  }

  Future<void> _scheduleNotificationsForDate(
      String date, String content) async {
    try {
      // Parse events from the content
      final events = MarkdownParser.parseEvents(date, content);

      // Cancel all existing notifications for this date first
      await _notificationService.cancelNotificationsForDate(date);

      // Schedule new notifications
      for (final event in events) {
        final eventId =
            NotificationService.generateEventId(event.displayTitle, event.time);
        await _notificationService.scheduleEventNotification(
          id: eventId,
          title: event.displayTitle,
          description: event.description,
          eventDateTime: event.time,
          date: date,
        );
      }

      if (events.isNotEmpty) {
        Log.i(
            '📅 FileMonitorService: Scheduled ${events.length} notifications for $date');
      }
    } catch (e) {
      Log.e('❌ FileMonitorService: Error scheduling notifications', error: e);
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _watchDebounceTimer?.cancel();
    _watchSubscription?.cancel();
    _watchSubscription = null;
    Log.i('📁 FileMonitorService: Disposed');
  }
}
