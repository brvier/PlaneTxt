import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/services/notification_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';

class FileMonitorService {
  static final FileMonitorService _instance = FileMonitorService._internal();
  factory FileMonitorService() => _instance;
  FileMonitorService._internal();

  Directory? _dailiesDirectory;
  Timer? _pollingTimer;
  final Map<String, DateTime> _lastModified = {};
  int _reviewCounter = 0;
  static const Duration _pollingInterval = Duration(seconds: 5);

  Future<void> initialize(Directory dailiesDirectory) async {
    _dailiesDirectory = dailiesDirectory;
    
    if (!dailiesDirectory.existsSync()) {
      Log.e('📁 FileMonitorService: Dailies directory does not exist');
      return;
    }

    Log.i('📁 FileMonitorService: Starting file monitoring for ${dailiesDirectory.path}');
    
    // Schedule notifications for existing events on startup
    await _scheduleExistingEvents();
    
    // Start polling for file changes
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      _checkForFileChanges();
    });
  }

  Future<void> _checkForFileChanges() async {
    if (_dailiesDirectory == null) return;
    
    try {
      final files = _dailiesDirectory!.listSync()
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
      final datesToRemove = _lastModified.keys.where((date) => !existingDates.contains(date)).toList();
      for (final date in datesToRemove) {
        _lastModified.remove(date);
        // Cancel notifications for deleted files
        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.cancelNotificationsForDate(date);
        Log.i('🗑️  FileMonitorService: Cancelled notifications for deleted date file: $date');
      }
      
      // Periodically review all notifications (every 10 file checks, roughly every 50 seconds)
      _reviewCounter++;
      if (_reviewCounter >= 10) {
        _reviewCounter = 0;
        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.reviewNotifications(_dailiesDirectory!);
      }
      
    } catch (e) {
      Log.e('❌ FileMonitorService: Error checking for file changes', e);
    }
  }

  Future<void> _handleFileChange(String date, String filePath) async {
    try {
      Log.i('📁 FileMonitorService: File changed - $date');
      
      final file = File(filePath);
      if (!file.existsSync()) {
        Log.w('📁 FileMonitorService: File no longer exists - $date');
        return;
      }
      
      final content = await file.readAsString();
      await _scheduleNotificationsForDate(date, content);
      
    } catch (e) {
      Log.e('❌ FileMonitorService: Error handling file change', e);
    }
  }

  Future<void> _scheduleExistingEvents() async {
    if (_dailiesDirectory == null) return;
    
    try {
      Log.i('📁 FileMonitorService: Scheduling notifications for existing events...');
      
      // Review existing notifications first to remove invalid ones
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.reviewNotifications(_dailiesDirectory!);
      
      final files = _dailiesDirectory!.listSync()
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
      
      Log.i('📁 FileMonitorService: Scheduled notifications for $scheduledCount files');
      
    } catch (e) {
      Log.e('❌ FileMonitorService: Error scheduling existing events', e);
    }
  }

  Future<void> _scheduleNotificationsForDate(String date, String content) async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      
      // Parse events from the content
      final events = MarkdownParser.parseEvents(date, content);
      
      // Cancel all existing notifications for this date first
      await notificationService.cancelNotificationsForDate(date);
      
      // Schedule new notifications
      for (final event in events) {
        final eventId = NotificationService.generateEventId(event.displayTitle, event.time);
        await notificationService.scheduleEventNotification(
          id: eventId,
          title: event.displayTitle,
          description: event.description,
          eventDateTime: event.time,
          date: date,
        );
      }
      
      if (events.isNotEmpty) {
        Log.i('📅 FileMonitorService: Scheduled ${events.length} notifications for $date');
      }
      
    } catch (e) {
      Log.e('❌ FileMonitorService: Error scheduling notifications', e);
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    Log.i('📁 FileMonitorService: Disposed');
  }
}