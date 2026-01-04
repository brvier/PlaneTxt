import 'package:planova/models/calendar_event.dart';
import 'package:planova/utils/logger.dart';

class IcsParserService {
  /// Parse ICS content and extract calendar events
  /// Returns a list of CalendarEvent objects
  static List<CalendarEvent> parseIcsContent(String icsContent) {
    final events = <CalendarEvent>[];

    try {
      Log.d('📅 IcsParserService: Starting to parse ICS content');

      // Extract all VEVENT components using regex
      final vEventComponents = _extractVEventComponents(icsContent);
      Log.d(
          '📅 IcsParserService: Found ${vEventComponents.length} VEVENT components to process');

      for (final vEvent in vEventComponents) {
        try {
          final event = _parseVEvent(vEvent);
          if (event != null) {
            events.add(event);
            Log.d(
                '📅 IcsParserService: Successfully parsed event: ${event.title}');
          } else {
            Log.w('⚠️  IcsParserService: VEVENT parsing returned null');
          }
        } catch (e) {
          Log.e('❌ IcsParserService: Error parsing VEVENT component', error: e);
          continue;
        }
      }

      Log.i(
          '📅 IcsParserService: Successfully parsed ${events.length} events from ICS content');
    } catch (e) {
      Log.e('❌ IcsParserService: Error parsing ICS content', error: e);
      throw Exception('Failed to parse ICS content: ${e.toString()}');
    }

    return events;
  }

  /// Extract VEVENT components from ICS content
  static List<String> _extractVEventComponents(String icsContent) {
    final vEvents = <String>[];

    // Use regex to find all VEVENT blocks
    final pattern = RegExp(r'BEGIN:VEVENT([\s\S]*?)END:VEVENT');
    final matches = pattern.allMatches(icsContent);

    for (final match in matches) {
      vEvents.add('BEGIN:VEVENT${match.group(1)}END:VEVENT');
    }

    return vEvents;
  }

  /// Parse a VEVENT component into a CalendarEvent
  static CalendarEvent? _parseVEvent(String vEventContent) {
    final properties = _parseIcsProperties(vEventContent);

    Log.d(
        '📅 IcsParserService: VEVENT properties: ${properties.keys.join(", ")}');

    // Extract required properties
    final dtStart = properties['DTSTART'];
    final summary = properties['SUMMARY'];

    if (dtStart == null || summary == null) {
      Log.w(
          '⚠️  IcsParserService: VEVENT missing required properties (DTSTART: $dtStart, SUMMARY: $summary)');
      return null;
    }

    // Parse datetime
    final eventDateTime = _parseIcsDateTime(dtStart);
    if (eventDateTime == null) {
      Log.w('⚠️  IcsParserService: Failed to parse DTSTART: $dtStart');
      return null;
    }

    // Format date as YYYYMMDD
    final date =
        '${eventDateTime.year}${eventDateTime.month.toString().padLeft(2, '0')}${eventDateTime.day.toString().padLeft(2, '0')}';

    // Extract optional properties
    final description = properties['DESCRIPTION'] ?? '';

    Log.d(
        '📅 IcsParserService: Parsed event - Title: $summary, Date: $date, Time: $eventDateTime');

    return CalendarEvent(
      title: summary,
      time: eventDateTime,
      description: description,
      date: date,
    );
  }

  /// Parse ICS properties from component content
  static Map<String, String> _parseIcsProperties(String componentContent) {
    final properties = <String, String>{};
    final lines = componentContent.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Skip BEGIN/END lines and empty lines
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('BEGIN:') ||
          trimmedLine.startsWith('END:')) {
        continue;
      }

      // Split property name and value
      final colonIndex = trimmedLine.indexOf(':');
      if (colonIndex > 0) {
        final propertyName = trimmedLine.substring(0, colonIndex);
        final propertyValue = trimmedLine.substring(colonIndex + 1).trim();

        // Remove any parameters from property name (e.g., DTSTART;TZID=...)
        final cleanPropertyName = propertyName.split(';')[0];

        properties[cleanPropertyName] = propertyValue;
      }
    }

    return properties;
  }

  /// Parse ICS datetime format
  static DateTime? _parseIcsDateTime(String dateTimeStr) {
    try {
      // Handle different datetime formats
      if (dateTimeStr.endsWith('Z')) {
        // UTC format: 20231225T100000Z
        return _parseUtcDateTime(dateTimeStr);
      } else if (dateTimeStr.contains('T')) {
        // Local format: 20231225T100000
        return _parseLocalDateTime(dateTimeStr);
      } else {
        // Date only format: 20231225
        return _parseDateOnly(dateTimeStr);
      }
    } catch (e) {
      Log.e('❌ IcsParserService: Error parsing datetime: $dateTimeStr',
          error: e);
      return null;
    }
  }

  /// Parse UTC datetime (ends with Z)
  static DateTime _parseUtcDateTime(String utcDateTime) {
    // Remove Z suffix
    final cleanDateTime = utcDateTime.substring(0, utcDateTime.length - 1);

    // Parse format: yyyyMMddTHHmmss
    final year = int.parse(cleanDateTime.substring(0, 4));
    final month = int.parse(cleanDateTime.substring(4, 6));
    final day = int.parse(cleanDateTime.substring(6, 8));
    final hour = int.parse(cleanDateTime.substring(9, 11));
    final minute = int.parse(cleanDateTime.substring(11, 13));
    final second = int.parse(cleanDateTime.substring(13, 15));

    // Convert from UTC to local time
    return DateTime(year, month, day, hour, minute, second).toLocal();
  }

  /// Parse local datetime
  static DateTime _parseLocalDateTime(String localDateTime) {
    // Parse format: yyyyMMddTHHmmss
    final year = int.parse(localDateTime.substring(0, 4));
    final month = int.parse(localDateTime.substring(4, 6));
    final day = int.parse(localDateTime.substring(6, 8));
    final hour = int.parse(localDateTime.substring(9, 11));
    final minute = int.parse(localDateTime.substring(11, 13));
    final second = int.parse(localDateTime.substring(13, 15));

    return DateTime(year, month, day, hour, minute, second);
  }

  /// Parse date only (no time component)
  static DateTime _parseDateOnly(String dateOnly) {
    // Parse format: yyyyMMdd
    final year = int.parse(dateOnly.substring(0, 4));
    final month = int.parse(dateOnly.substring(4, 6));
    final day = int.parse(dateOnly.substring(6, 8));

    // Default to 9:00 AM for all-day events
    return DateTime(year, month, day, 9, 0, 0);
  }

  /// Validate that the content looks like ICS format
  static bool isValidIcsContent(String content) {
    if (content.isEmpty) return false;

    // Check for basic ICS structure
    final hasBeginCalendar = content.contains('BEGIN:VCALENDAR');
    final hasEndCalendar = content.contains('END:VCALENDAR');
    final hasVersion = content.contains('VERSION:');

    return hasBeginCalendar && hasEndCalendar && hasVersion;
  }
}
