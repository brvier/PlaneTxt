import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

  static const String _channelId = 'event_reminders';
  static const String _channelName = 'Event Reminders';
  static const String _channelDesc =
      'Notifications for upcoming events in Planova';

  NotificationDetails get _notificationDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
          defaultActionName: 'Open notification',
        ),
      );

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      Log.i('NotificationService: timezone=$timeZoneName');
    } catch (e) {
      Log.e('NotificationService: Failed to get timezone', error: e);
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        Log.i('Notification tapped: ${response.payload}');
      },
    );

    _initialized = true;

    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        );

        final enabled = await androidPlugin.areNotificationsEnabled();
        final canExact = await androidPlugin.canScheduleExactNotifications();
        Log.i(
            'NotificationService: notificationsEnabled=$enabled, canScheduleExact=$canExact');
      }
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return true;
    }

    try {
      final status = await Permission.notification.request();
      Log.i('NotificationService: POST_NOTIFICATIONS=$status');

      if (Platform.isAndroid) {
        final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
        if (!exactAlarmStatus.isGranted) {
          final newStatus = await Permission.scheduleExactAlarm.request();
          Log.i('NotificationService: SCHEDULE_EXACT_ALARM=$newStatus');
        }
      }

      return status.isGranted;
    } catch (e) {
      Log.e('NotificationService: permission request failed', error: e);
      return false;
    }
  }

  /// Fire an immediate notification right now. Use this to test if the
  /// notification channel and permissions work at all.
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    Log.i('NotificationService: Firing immediate test notification');
    await _notifications.show(
      0,
      'Planova Test',
      'If you see this, notifications work!',
      _notificationDetails,
      payload: 'test',
    );
    Log.i('NotificationService: show() completed');
  }

  /// Schedule a test notification 15 seconds from now using zonedSchedule.
  /// Tests all three modes so we can identify which AlarmManager API works.
  Future<void> showScheduledTestNotification() async {
    if (!_initialized) await initialize();

    final now = tz.TZDateTime.now(tz.local);

    // Test 1: alarmClock mode (setAlarmClock - most reliable, at 15s)
    final time1 = now.add(const Duration(seconds: 15));
    Log.i('NotificationService: TEST alarmClock at $time1');
    try {
      await _notifications.zonedSchedule(
        1,
        'Test: alarmClock mode',
        'This used setAlarmClock()',
        time1,
        _notificationDetails,
        payload: 'test_alarmClock',
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
      Log.i('NotificationService: alarmClock scheduled OK');
    } catch (e) {
      Log.e('NotificationService: alarmClock FAILED', error: e);
    }

    // Test 2: exactAllowWhileIdle mode (setExactAndAllowWhileIdle, at 30s)
    final time2 = now.add(const Duration(seconds: 30));
    Log.i('NotificationService: TEST exactAllowWhileIdle at $time2');
    try {
      await _notifications.zonedSchedule(
        2,
        'Test: exactAllowWhileIdle mode',
        'This used setExactAndAllowWhileIdle()',
        time2,
        _notificationDetails,
        payload: 'test_exact',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      Log.i('NotificationService: exactAllowWhileIdle scheduled OK');
    } catch (e) {
      Log.e('NotificationService: exactAllowWhileIdle FAILED', error: e);
    }

    // Test 3: inexactAllowWhileIdle mode (setAndAllowWhileIdle, at 45s)
    final time3 = now.add(const Duration(seconds: 45));
    Log.i('NotificationService: TEST inexactAllowWhileIdle at $time3');
    try {
      await _notifications.zonedSchedule(
        3,
        'Test: inexactAllowWhileIdle mode',
        'This used setAndAllowWhileIdle()',
        time3,
        _notificationDetails,
        payload: 'test_inexact',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      Log.i('NotificationService: inexactAllowWhileIdle scheduled OK');
    } catch (e) {
      Log.e('NotificationService: inexactAllowWhileIdle FAILED', error: e);
    }

    // Verify all are pending
    final pending = await _notifications.pendingNotificationRequests();
    Log.i(
        'NotificationService: ${pending.length} pending after scheduling tests');
    for (final n in pending) {
      Log.i('  pending: id=${n.id} title="${n.title}"');
    }
  }

  /// Fire a notification after a delay using a Dart Timer (bypasses AlarmManager).
  /// If this works but zonedSchedule doesn't, AlarmManager is broken.
  Future<void> showTimerTestNotification() async {
    if (!_initialized) await initialize();

    Log.i('NotificationService: Will fire notification via Dart Timer in 10s');
    Future.delayed(const Duration(seconds: 10), () async {
      Log.i('NotificationService: Timer fired, showing notification now');
      await _notifications.show(
        99,
        'Planova Timer Test',
        'This bypassed AlarmManager entirely (Dart Timer + show())',
        _notificationDetails,
        payload: 'test_timer',
      );
      Log.i('NotificationService: Timer notification shown');
    });
  }

  Future<AndroidScheduleMode> _getBestScheduleMode() async {
    if (!Platform.isAndroid) {
      return AndroidScheduleMode.alarmClock;
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> scheduleEventNotification({
    required int id,
    required String title,
    required String description,
    required DateTime eventDateTime,
    required String date,
  }) async {
    if (!_initialized) await initialize();

    // Notification fires 1 hour before event
    final notificationTime = eventDateTime.subtract(const Duration(hours: 1));

    if (notificationTime.isBefore(DateTime.now())) {
      Log.d(
          'NotificationService: skip past notification for "$title" at $notificationTime');
      return;
    }

    final scheduledTZ = tz.TZDateTime.from(notificationTime, tz.local);
    final mode = await _getBestScheduleMode();

    final eventHour = eventDateTime.hour.toString().padLeft(2, '0');
    final eventMinute = eventDateTime.minute.toString().padLeft(2, '0');
    final timeStr = '$eventHour:$eventMinute';

    try {
      await _notifications.zonedSchedule(
        id,
        '$timeStr - $title',
        description,
        scheduledTZ,
        _notificationDetails,
        payload: 'event_${date}_$id',
        androidScheduleMode: mode,
      );

      // Verify the notification is actually pending
      final pending = await _notifications.pendingNotificationRequests();
      final found = pending.any((n) => n.id == id);

      Log.i(
          'NotificationService: scheduled id=$id "$title" at $scheduledTZ mode=$mode verified=$found');
    } catch (e) {
      Log.e('NotificationService: FAILED to schedule "$title"', error: e);
      // Try inexact as last resort
      if (mode != AndroidScheduleMode.inexactAllowWhileIdle) {
        try {
          await _notifications.zonedSchedule(
            id,
            '$timeStr - $title',
            description,
            scheduledTZ,
            _notificationDetails,
            payload: 'event_${date}_$id',
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          Log.i('NotificationService: scheduled "$title" with inexact fallback');
        } catch (e2) {
          Log.e('NotificationService: inexact fallback also failed', error: e2);
        }
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  Future<void> cancelNotificationsForDate(String date) async {
    final pending = await _notifications.pendingNotificationRequests();
    for (final n in pending) {
      final payload = n.payload ?? '';
      if (payload.startsWith('event_${date}_')) {
        await _notifications.cancel(n.id);
      }
    }
  }

  static int generateEventId(String eventTitle, DateTime eventDateTime) {
    final combined = '${eventTitle}_${eventDateTime.millisecondsSinceEpoch}';
    return combined.hashCode & 0x7FFFFFFF;
  }

  /// Get a diagnostic string with current notification system status
  Future<String> getDiagnostics() async {
    if (!_initialized) await initialize();

    final lines = <String>[];

    lines.add('Initialized: $_initialized');
    lines.add('Timezone: ${tz.local.name}');
    lines.add('Now: ${tz.TZDateTime.now(tz.local)}');

    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        final canExact = await androidPlugin.canScheduleExactNotifications();
        lines.add('Notifications enabled: $enabled');
        lines.add('Can schedule exact: $canExact');
      }
    }

    final pending = await _notifications.pendingNotificationRequests();
    lines.add('Pending notifications: ${pending.length}');
    for (final n in pending) {
      lines.add('  id=${n.id} title="${n.title}" payload=${n.payload}');
    }

    return lines.join('\n');
  }

  Future<void> reviewNotifications(Directory dailiesDirectory) async {
    if (!_initialized) await initialize();

    try {
      final pending = await _notifications.pendingNotificationRequests();
      if (pending.isEmpty) return;

      Log.d(
          'NotificationService: reviewing ${pending.length} pending notifications');

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
            validEventsByDate[date] = events
                .map((e) => generateEventId(e.displayTitle, e.time))
                .toSet();
          } catch (e) {
            Log.e('NotificationService: error parsing $fileName', error: e);
          }
        }
      }

      final now = DateTime.now();
      int removedCount = 0;

      for (final notification in pending) {
        final payload = notification.payload ?? '';
        if (!payload.startsWith('event_')) continue;

        final parts = payload.split('_');
        if (parts.length < 3) {
          await _notifications.cancel(notification.id);
          removedCount++;
          continue;
        }

        final date = parts[1];
        final notificationId = int.tryParse(parts[2]);

        // Remove notifications for past dates
        if (date.length == 8) {
          try {
            final year = int.parse(date.substring(0, 4));
            final month = int.parse(date.substring(4, 6));
            final day = int.parse(date.substring(6, 8));
            final eventDate = DateTime(year, month, day);
            if (eventDate.add(const Duration(hours: 25)).isBefore(now)) {
              await _notifications.cancel(notification.id);
              removedCount++;
              continue;
            }
          } catch (_) {}
        }

        // Remove if date file no longer exists
        final dateFile = File('${dailiesDirectory.path}/$date.md');
        if (!dateFile.existsSync()) {
          await _notifications.cancel(notification.id);
          removedCount++;
          continue;
        }

        // Remove if event no longer exists in file
        if (notificationId != null) {
          final validEvents = validEventsByDate[date];
          if (validEvents == null || !validEvents.contains(notificationId)) {
            await _notifications.cancel(notification.id);
            removedCount++;
            continue;
          }
        }
      }

      if (removedCount > 0) {
        Log.i('NotificationService: removed $removedCount stale notifications');
      }
    } catch (e) {
      Log.e('NotificationService: error reviewing notifications', error: e);
    }
  }
}
