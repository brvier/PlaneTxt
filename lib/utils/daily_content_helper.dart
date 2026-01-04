import 'package:planova/utils/logger.dart';

/// Utility functions for working with daily file content
class DailyContentHelper {
  /// Inserts content after the first header matching the given regex pattern.
  /// If no matching header is found, appends the content to the end.
  ///
  /// [content] - The existing daily file content
  /// [newContent] - The new content to insert (e.g., a todo or event)
  /// [headerRegex] - Regex pattern to match the header (e.g., r'^##\s+Tasks?')
  ///
  /// Returns the updated content with newContent inserted after the matching header.
  static String insertAfterHeader(
    String content,
    String newContent,
    String headerRegex,
  ) {
    if (headerRegex.isEmpty) {
      // If no regex is set, append to end
      return content.isEmpty ? newContent : '$content\n\n$newContent';
    }

    try {
      final regex = RegExp(headerRegex, multiLine: true);
      final lines = content.split('\n');

      // Find the first line that matches the header regex
      int? headerIndex;
      for (int i = 0; i < lines.length; i++) {
        if (regex.hasMatch(lines[i])) {
          headerIndex = i;
          break;
        }
      }

      if (headerIndex == null) {
        // No matching header found, append to end
        return content.isEmpty ? newContent : '$content\n\n$newContent';
      }

      // Find the insertion point (after the header and any empty lines)
      int insertIndex = headerIndex + 1;

      // Skip empty lines after the header
      while (insertIndex < lines.length && lines[insertIndex].trim().isEmpty) {
        insertIndex++;
      }

      // Insert the new content
      final beforeInsert = lines.sublist(0, insertIndex).join('\n');
      final afterInsert = lines.sublist(insertIndex).join('\n');

      // Check if the next line after insertion starts with a header (#)
      final nextLineAfterInsert =
          afterInsert.split('\n').firstOrNull?.trim() ?? '';
      final isNextLineHeader = nextLineAfterInsert.startsWith('#');

      // If there's content after, add a newline before it
      if (afterInsert.isNotEmpty) {
        // Add extra newline if next line is a header to separate sections
        if (isNextLineHeader) {
          return '$beforeInsert\n$newContent\n\n$afterInsert';
        } else {
          return '$beforeInsert\n$newContent\n$afterInsert';
        }
      } else {
        // If we're at the end, just append
        return '$beforeInsert\n$newContent';
      }
    } catch (e) {
      // If regex is invalid, fall back to appending
      Log.e('?? DailyContentHelper: Invalid regex pattern "$headerRegex"',
          error: e);
      return content.isEmpty ? newContent : '$content\n\n$newContent';
    }
  }

  /// Inserts multiple events into the events section in chronological order.
  /// Creates an events section if one doesn't exist.
  static String insertEventsChronologically(
    String content,
    List<String> eventLines, // List of event lines like "- @09:00 Meeting"
    String eventHeaderRegex,
  ) {
    try {
      final regex = RegExp(eventHeaderRegex, multiLine: true);
      final lines = content.split('\n');

      // Find the events section
      int? eventsHeaderIndex;
      int? eventsSectionEndIndex;

      for (int i = 0; i < lines.length; i++) {
        if (regex.hasMatch(lines[i])) {
          eventsHeaderIndex = i;

          // Find the end of the events section (next header or end of file)
          eventsSectionEndIndex = i + 1;
          while (eventsSectionEndIndex! < lines.length) {
            final line = lines[eventsSectionEndIndex].trim();
            if (line.isEmpty) {
              eventsSectionEndIndex++;
              continue;
            }
            if (line.startsWith('##') || line.startsWith('#')) {
              break;
            }
            if (_isEventLine(line)) {
              eventsSectionEndIndex++;
              continue;
            }
            // If it's not an event line and not a header, it's the end of events section
            break;
          }
          break;
        }
      }

      // Sort events chronologically
      final sortedEvents = _sortEventLinesChronologically(eventLines);

      if (eventsHeaderIndex != null) {
        // Events section exists - insert sorted events
        final beforeEvents = lines.sublist(0, eventsHeaderIndex + 1);
        final afterEventsHeader =
            lines.sublist(eventsHeaderIndex + 1, eventsSectionEndIndex);
        final afterEventsSection =
            lines.sublist(eventsSectionEndIndex ?? lines.length);

        // Filter out existing events to avoid duplicates
        final existingEvents =
            afterEventsHeader.where((line) => _isEventLine(line.trim()));
        final newEvents = sortedEvents.where((newEvent) => !existingEvents
            .any((existing) => _eventsAreSame(existing.trim(), newEvent)));

        return [
          ...beforeEvents,
          ...afterEventsHeader.where((line) => !_isEventLine(line.trim())),
          ...newEvents,
          if (afterEventsSection.isNotEmpty) ...afterEventsSection,
        ].join('\n');
      } else {
        // No events section - create one with sorted events
        if (content.isNotEmpty && !content.endsWith('\n')) {
          return '$content\n\n## Events\n\n${sortedEvents.join('\n')}';
        } else {
          return '$content\n## Events\n\n${sortedEvents.join('\n')}';
        }
      }
    } catch (e) {
      Log.e('?? DailyContentHelper: Error inserting events chronologically',
          error: e);
      // Fallback: append events at the end
      if (content.isNotEmpty && !content.endsWith('\n')) {
        return '$content\n\n${eventLines.join('\n')}';
      } else {
        return '$content\n${eventLines.join('\n')}';
      }
    }
  }

  /// Check if a line is an event line
  static bool _isEventLine(String line) {
    return RegExp(r'^\s*-\s*@\d{1,2}:\d{2}').hasMatch(line);
  }

  /// Sort event lines chronologically by their time
  static List<String> _sortEventLinesChronologically(List<String> eventLines) {
    // Extract time from each event line and sort
    final eventsWithTimes = eventLines.map((line) {
      final timeMatch = RegExp(r'@(\d{1,2}):(\d{2})').firstMatch(line);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        final timeValue = hour * 100 +
            minute; // Convert to sortable number (e.g., 930 for 09:30)
        return {'line': line, 'time': timeValue};
      }
      return {'line': line, 'time': 0}; // Default to 0 if no time found
    }).toList();

    // Sort by time value
    eventsWithTimes
        .sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));

    return eventsWithTimes.map((e) => e['line'] as String).toList();
  }

  /// Check if two event lines represent the same event (basic comparison)
  static bool _eventsAreSame(String existingEvent, String newEvent) {
    // Extract the core content (remove bullet and time)
    final existingCore =
        existingEvent.replaceAll(RegExp(r'^\s*-\s*@\d{1,2}:\d{2}\s*'), '');
    final newCore =
        newEvent.replaceAll(RegExp(r'^\s*-\s*@\d{1,2}:\d{2}\s*'), '');

    return existingCore.trim() == newCore.trim();
  }
}
