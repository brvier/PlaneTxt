import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Linux initialization settings
    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    // Request notification permission (only on platforms that support it)
    // Linux doesn't require explicit permission requests
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Desktop platforms don't use permission_handler
      return true;
    }

    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      Log.e('Warning: Could not request permissions', e);
      return false;
    }
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    // Handle notification tap - could open the app to the specific event
    Log.i('Notification tapped: ${response.payload}');
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
      Log.d('Cannot schedule notification for past time: $notificationTime');
      return;
    }

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

    // Linux notification details
    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
      defaultActionName: 'Open notification',
    );

    // Combined notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    // Format event time as HH:MM
    final eventHour = eventDateTime.hour.toString().padLeft(2, '0');
    final eventMinute = eventDateTime.minute.toString().padLeft(2, '0');
    final eventTimeString = '$eventHour:$eventMinute';

    // Schedule the notification
    await _notifications.zonedSchedule(
      id,
      '$eventTimeString - $title',
      description,
      tz.TZDateTime.from(notificationTime, tz.local),
      notificationDetails,
      payload: 'event_${date}_$id',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    Log.i('Scheduled notification for event: $title at $notificationTime');
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    Log.d('Cancelled notification with id: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    Log.d('Cancelled all notifications');
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
        Log.d('?? NotificationService: No pending notifications to review');
        return;
      }

      Log.d(
          '?? NotificationService: Reviewing ${pending.length} pending notifications...');

      // Build a map of valid events by date
      final validEventsByDate = <String, Set<int>>{};

      if (dailiesDirectory.existsSync()) {
        final files = dailiesDirectory
            .listSync()
            .where((entity) => entity is File && entity.path.endsWith('.md'))
            .cast<File>();

        for (final file in files) {
          final fileName = path.basename(file.path);
          final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
          if (dateMatch == null) continue;

          final date = dateMatch.group(1)!;
          try {
            final content = await file.readAsString();
            final events = MarkdownParser.parseEvents(date, content);

            validEventsByDate[date] = events.map((event) {
              return generateEventId(event.displayTitle, event.time);
            }).toSet();
          } catch (e) {
            Log.e('? NotificationService: Error parsing file $fileName', e);
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
          Log.w(
              '???  NotificationService: Removed notification with invalid payload: $payload');
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
              Log.d(
                  '???  NotificationService: Removed notification for past event date: $date');
              continue;
            }
          }
        } catch (e) {
          Log.e('? NotificationService: Error parsing date from payload', e);
        }

        // Check if the date file still exists
        final dateFile = File('${dailiesDirectory.path}/$date.md');
        if (!dateFile.existsSync()) {
          await _notifications.cancel(notification.id);
          removedCount++;
          Log.d(
              '???  NotificationService: Removed notification for non-existent date file: $date');
          continue;
        }

        // Check if this notification ID matches a valid event
        if (notificationId != null) {
          final validEvents = validEventsByDate[date];
          if (validEvents == null || !validEvents.contains(notificationId)) {
            await _notifications.cancel(notification.id);
            removedCount++;
            Log.d(
                '???  NotificationService: Removed notification for non-existent event: ID $notificationId, date $date');
            continue;
          }
        }
      }

      if (removedCount > 0) {
        Log.i(
            '? NotificationService: Removed $removedCount invalid notifications');
      } else {
        Log.d('? NotificationService: All notifications are valid');
      }
    } catch (e) {
      Log.e('? NotificationService: Error reviewing notifications', e);
    }
  }
}
