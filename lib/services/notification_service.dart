import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

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
      'Event Reminders',
      channelDescription: 'Notifications for upcoming events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
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

    // Schedule the notification
    await _notifications.zonedSchedule(
      id,
      'Event Reminder',
      '$title starts in 1 hour',
      tz.TZDateTime.from(notificationTime, tz.local),
      notificationDetails,
      payload: 'event_$id',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
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

  // Helper method to generate a unique ID for events
  static int generateEventId(String eventTitle, DateTime eventDateTime) {
    return eventTitle.hashCode ^ eventDateTime.millisecondsSinceEpoch.hashCode;
  }
}