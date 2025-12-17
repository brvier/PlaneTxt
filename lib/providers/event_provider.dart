import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:planova/models/calendar_event.dart';
import 'package:planova/services/notification_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';

class EventProvider extends ChangeNotifier {
  EventProvider();

  Future<void> scheduleEventNotifications(String date, String content) async {
    try {
      Log.i('📅 EventProvider: Scheduling event notifications for $date');

      final notificationService = NotificationService();
      await notificationService.initialize();

      final events = MarkdownParser.parseEvents(date, content);

      // Cancel existing notifications for this date
      await notificationService.cancelNotificationsForDate(date);

      // Schedule new notifications
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
          '📅 EventProvider: Scheduled ${events.length} event notifications for $date');
    } catch (e) {
      Log.e('❌ EventProvider: Error scheduling event notifications', e);
      rethrow;
    }
  }

  List<CalendarEvent> parseEvents(String date, String content) {
    try {
      final events = MarkdownParser.parseEvents(date, content);
      events.sort((a, b) => a.time.compareTo(b.time));
      Log.d('📅 EventProvider: Parsed ${events.length} events from content');
      return events;
    } catch (e) {
      Log.e('❌ EventProvider: Error parsing events', e);
      return [];
    }
  }

  @override
  void dispose() {
    Log.i('📅 EventProvider: Disposed');
    super.dispose();
  }
}
