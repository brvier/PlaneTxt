import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/calendar_event.dart';
import 'notification_service.dart';

class FileMonitorService {
  static final FileMonitorService _instance = FileMonitorService._internal();
  factory FileMonitorService() => _instance;
  FileMonitorService._internal();

  Directory? _dailiesDirectory;
  Timer? _pollingTimer;
  final Map<String, DateTime> _lastModified = {};
  static const Duration _pollingInterval = Duration(seconds: 5);

  Future<void> initialize(Directory dailiesDirectory) async {
    _dailiesDirectory = dailiesDirectory;
    
    if (!dailiesDirectory.existsSync()) {
      print('📁 FileMonitorService: Dailies directory does not exist');
      return;
    }

    print('📁 FileMonitorService: Starting file monitoring for ${dailiesDirectory.path}');
    
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
      
      for (final file in files) {
        final fileName = path.basename(file.path);
        final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
        if (dateMatch == null) continue;
        
        final date = dateMatch.group(1)!;
        final lastModified = file.lastModifiedSync();
        
        // Check if file was modified since last check
        if (_lastModified[date] == null || 
            _lastModified[date]!.isBefore(lastModified)) {
          _lastModified[date] = lastModified;
          await _handleFileChange(date, file.path);
        }
      }
    } catch (e) {
      print('❌ FileMonitorService: Error checking for file changes: $e');
    }
  }

  Future<void> _handleFileChange(String date, String filePath) async {
    try {
      print('📁 FileMonitorService: File changed - $date');
      
      final file = File(filePath);
      if (!file.existsSync()) {
        print('📁 FileMonitorService: File no longer exists - $date');
        return;
      }
      
      final content = await file.readAsString();
      await _scheduleNotificationsForDate(date, content);
      
    } catch (e) {
      print('❌ FileMonitorService: Error handling file change: $e');
    }
  }

  Future<void> _scheduleExistingEvents() async {
    if (_dailiesDirectory == null) return;
    
    try {
      print('📁 FileMonitorService: Scheduling notifications for existing events...');
      
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
      
      print('📁 FileMonitorService: Scheduled notifications for $scheduledCount files');
      
    } catch (e) {
      print('❌ FileMonitorService: Error scheduling existing events: $e');
    }
  }

  Future<void> _scheduleNotificationsForDate(String date, String content) async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      
      // Parse events from the content
      final events = _parseEventsFromContent(date, content);
      
      // Cancel existing notifications for this date first
      for (final event in events) {
        final eventId = NotificationService.generateEventId(event.displayTitle, event.time);
        await notificationService.cancelNotification(eventId);
      }
      
      // Schedule new notifications
      for (final event in events) {
        final eventId = NotificationService.generateEventId(event.displayTitle, event.time);
        await notificationService.scheduleEventNotification(
          id: eventId,
          title: event.displayTitle,
          description: event.description,
          eventDateTime: event.time,
        );
      }
      
      if (events.isNotEmpty) {
        print('📅 FileMonitorService: Scheduled ${events.length} notifications for $date');
      }
      
    } catch (e) {
      print('❌ FileMonitorService: Error scheduling notifications: $e');
    }
  }

  List<CalendarEvent> _parseEventsFromContent(String date, String content) {
    final events = <CalendarEvent>[];
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final timeMatch = RegExp(r'@(\d{1,2}):(\d{2})').firstMatch(line);
      
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        
        // Parse date from YYYYMMDD format
        final year = int.parse(date.substring(0, 4));
        final month = int.parse(date.substring(4, 6));
        final day = int.parse(date.substring(6, 8));
        
        final eventTime = DateTime(year, month, day, hour, minute);
        final title = line.trim();
        final description = _extractEventDescription(lines, i);
        
        events.add(CalendarEvent(
          title: title,
          time: eventTime,
          description: description,
          date: date,
        ));
      }
    }
    
    return events;
  }

  String _extractEventDescription(List<String> lines, int eventLineIndex) {
    final description = StringBuffer();
    
    // Look for description in the next few lines
    for (int i = eventLineIndex + 1; i < lines.length && i < eventLineIndex + 5; i++) {
      final line = lines[i].trim();
      
      // Stop if we hit another event, task, or empty line
      if (line.isEmpty || 
          RegExp(r'@\d{1,2}:\d{2}').hasMatch(line) ||
          RegExp(r'^\s*[-*]\s*\[[ x]\]').hasMatch(line)) {
        break;
      }
      
      // Add non-empty lines to description
      if (line.isNotEmpty) {
        if (description.isNotEmpty) description.write('\n');
        description.write(line);
      }
    }
    
    return description.toString();
  }

  void dispose() {
    _pollingTimer?.cancel();
    print('📁 FileMonitorService: Disposed');
  }
}