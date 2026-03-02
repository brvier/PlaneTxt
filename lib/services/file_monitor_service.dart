import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/services/notification_service.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';

class FileMonitorService {
  static final FileMonitorService _instance = FileMonitorService._internal();
  factory FileMonitorService() => _instance;
  FileMonitorService._internal();

  Directory? _dailiesDirectory;
  Timer? _pollingTimer;
  final Map<String, DateTime> _lastModified = {};
  final NotificationService _notificationService = NotificationService();
  static const Duration _pollingInterval = Duration(seconds: 5);

  // Track dates recently scheduled by DailyFileProvider to avoid
  // the FileMonitorService cancelling those notifications immediately.
  final Map<String, DateTime> _recentlyScheduledDates = {};
  static const Duration _debounceWindow = Duration(seconds: 10);

  Future<void> initialize(Directory dailiesDirectory) async {
    _dailiesDirectory = dailiesDirectory;

    if (!dailiesDirectory.existsSync()) {
      Log.e('📁 FileMonitorService: Dailies directory does not exist');
      return;
    }

    await _notificationService.initialize();

    Log.i(
        '📁 FileMonitorService: Starting file monitoring for ${dailiesDirectory.path}');

    // Schedule notifications for existing events on startup
    await _scheduleExistingEvents();

    // Start polling for file changes
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      _checkForFileChanges();
    });
  }

  Future<void> _checkForFileChanges() async {
    if (_dailiesDirectory == null) return;

    try {
      final dir = StorageService().dailiesDirectory ?? _dailiesDirectory!;
      final files = dir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.md'))
          .cast<File>();

      // Track which dates still have files
      final existingDates = <String>{};

      for (final file in files) {
        final fileName = path.basename(file.path);
        final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
        if (dateMatch == null) continue;

        final date = dateMatch.group(1)!;
        existingDates.add(date);
        final lastModified = file.lastModifiedSync();

        // Check if file was modified since last check
        if (_lastModified[date] == null ||
            _lastModified[date]!.isBefore(lastModified)) {
          _lastModified[date] = lastModified;
          await _handleFileChange(date, file.path);
        }
      }

      // Remove lastModified entries for dates that no longer have files
      final datesToRemove = _lastModified.keys
          .where((date) => !existingDates.contains(date))
          .toList();
      for (final date in datesToRemove) {
        _lastModified.remove(date);
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

  Future<void> _handleFileChange(String date, String filePath) async {
    try {
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

      final file = File(filePath);
      if (!file.existsSync()) {
        Log.w('📁 FileMonitorService: File no longer exists - $date');
        return;
      }

      final content = await file.readAsString();
      await _scheduleNotificationsForDate(date, content);
    } catch (e) {
      Log.e('❌ FileMonitorService: Error handling file change', error: e);
    }
  }

  Future<void> _scheduleExistingEvents() async {
    if (_dailiesDirectory == null) return;

    try {
      final dir = StorageService().dailiesDirectory ?? _dailiesDirectory!;
      Log.i(
          '📁 FileMonitorService: Scheduling notifications for existing events...');

      // Review existing notifications first to remove invalid ones
      await _notificationService.reviewNotifications(dir);

      final files = dir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.md'))
          .cast<File>();

      int scheduledCount = 0;
      for (final file in files) {
        final fileName = path.basename(file.path);
        final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
        if (dateMatch == null) continue;

        final date = dateMatch.group(1)!;
        final content = await file.readAsString();

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
    Log.i('📁 FileMonitorService: Disposed');
  }
}
