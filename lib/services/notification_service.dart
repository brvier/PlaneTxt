import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:path/path.dart' as path;
import '../models/calendar_event.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    // Request notification permission
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    // Handle notification tap - could open the app to the specific event
    print('Notification tapped: ${response.payload}');
  }

  Future<void> scheduleEventNotification({
    required int id,
    required String title,
    required String description,
    required DateTime eventDateTime,
    required String date,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Calculate notification time (1 hour before event)
    final notificationTime = eventDateTime.subtract(const Duration(hours: 1));
    
    // Don't schedule if the notification time has already passed
    if (notificationTime.isBefore(DateTime.now())) {
      print('Cannot schedule notification for past time: $notificationTime');
      return;
    }

    // Android notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Planova',
      channelDescription: 'Notifications for upcoming events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Combined notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Format event time as HH:MM
    final eventHour = eventDateTime.hour.toString().padLeft(2, '0');
    final eventMinute = eventDateTime.minute.toString().padLeft(2, '0');
    final eventTimeString = '$eventHour:$eventMinute';
    
    // Schedule the notification
    await _notifications.zonedSchedule(
      id,
      '$eventTimeString - $title',
      '$title',
      tz.TZDateTime.from(notificationTime, tz.local),
      notificationDetails,
      payload: 'event_${date}_$id',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('Scheduled notification for event: $title at $notificationTime');
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    print('Cancelled notification with id: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('Cancelled all notifications');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Cancel all notifications associated with a given YYYYMMDD date
  Future<void> cancelNotificationsForDate(String date) async {
    final pending = await _notifications.pendingNotificationRequests();
    for (final n in pending) {
      final payload = n.payload ?? '';
      if (payload.startsWith('event_${date}_')) {
        await _notifications.cancel(n.id);
      }
    }
  }

  // Helper method to generate a unique ID for events
  static int generateEventId(String eventTitle, DateTime eventDateTime) {
    return eventTitle.hashCode ^ eventDateTime.millisecondsSinceEpoch.hashCode;
  }

  /// Review existing notifications and remove invalid ones
  /// This checks:
  /// - Notifications for past events
  /// - Notifications for dates that no longer have files
  /// - Notifications that don't match current events in files
  Future<void> reviewNotifications(Directory dailiesDirectory) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final pending = await _notifications.pendingNotificationRequests();
      if (pending.isEmpty) {
        print('?? NotificationService: No pending notifications to review');
        return;
      }

      print('?? NotificationService: Reviewing ${pending.length} pending notifications...');

      // Build a map of valid events by date
      final validEventsByDate = <String, Set<int>>{};
      
      if (dailiesDirectory.existsSync()) {
        final files = dailiesDirectory.listSync()
            .where((entity) => entity is File && entity.path.endsWith('.md'))
            .cast<File>();

        for (final file in files) {
          final fileName = path.basename(file.path);
          final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
          if (dateMatch == null) continue;

          final date = dateMatch.group(1)!;
          try {
            final content = await file.readAsString();
            final events = _parseEventsFromContent(date, content);
            
            validEventsByDate[date] = events.map((event) {
              return generateEventId(event.displayTitle, event.time);
            }).toSet();
          } catch (e) {
            print('? NotificationService: Error parsing file $fileName: $e');
          }
        }
      }

      final now = DateTime.now();
      int removedCount = 0;

      for (final notification in pending) {
        final payload = notification.payload ?? '';
        
        // Only process event notifications (payload format: event_${date}_${id})
        if (!payload.startsWith('event_')) {
          continue;
        }

        final payloadParts = payload.split('_');
        if (payloadParts.length < 3) {
          // Invalid payload format, remove it
          await _notifications.cancel(notification.id);
          removedCount++;
          print('???  NotificationService: Removed notification with invalid payload: $payload');
          continue;
        }

        final date = payloadParts[1]; // YYYYMMDD format
        final notificationId = int.tryParse(payloadParts[2]);

        // Check if notification time has passed (notification is scheduled 1 hour before event)
        // The scheduled date should be in notification body or we need to parse it differently
        // Since we can't get the exact scheduled time from PendingNotificationRequest,
        // we'll check if the event date has passed
        try {
          if (date.length == 8) {
            final year = int.parse(date.substring(0, 4));
            final month = int.parse(date.substring(4, 6));
            final day = int.parse(date.substring(6, 8));
            final eventDate = DateTime(year, month, day);
            
            // If the event date has passed (more than 24 hours ago), remove notification
            if (eventDate.add(const Duration(hours: 25)).isBefore(now)) {
              await _notifications.cancel(notification.id);
              removedCount++;
              print('???  NotificationService: Removed notification for past event date: $date');
              continue;
            }
          }
        } catch (e) {
          print('? NotificationService: Error parsing date from payload: $e');
        }

        // Check if the date file still exists
        final dateFile = File('${dailiesDirectory.path}/$date.md');
        if (!dateFile.existsSync()) {
          await _notifications.cancel(notification.id);
          removedCount++;
          print('???  NotificationService: Removed notification for non-existent date file: $date');
          continue;
        }

        // Check if this notification ID matches a valid event
        if (notificationId != null) {
          final validEvents = validEventsByDate[date];
          if (validEvents == null || !validEvents.contains(notificationId)) {
            await _notifications.cancel(notification.id);
            removedCount++;
            print('???  NotificationService: Removed notification for non-existent event: ID $notificationId, date $date');
            continue;
          }
        }
      }

      if (removedCount > 0) {
        print('? NotificationService: Removed $removedCount invalid notifications');
      } else {
        print('? NotificationService: All notifications are valid');
      }

    } catch (e) {
      print('? NotificationService: Error reviewing notifications: $e');
    }
  }

  /// Parse events from content string (duplicate of logic in file_monitor_service and file_provider)
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
        
        // Extract description from following lines
        String description = '';
        for (int j = i + 1; j < lines.length && j < i + 5; j++) {
          final descLine = lines[j].trim();
          if (descLine.isEmpty || 
              RegExp(r'@\d{1,2}:\d{2}').hasMatch(descLine) ||
              RegExp(r'^\s*[-*]\s*\[[ x]\]').hasMatch(descLine)) {
            break;
          }
          if (descLine.isNotEmpty) {
            if (description.isNotEmpty) description += '\n';
            description += descLine;
          }
        }
        
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
}
