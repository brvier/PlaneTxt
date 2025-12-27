import 'package:planova/models/calendar_event.dart';
import 'package:planova/utils/logger.dart';

class MarkdownParser {
  /// Parse tasks from markdown content
  static List<TaskItem> parseTasks(String content) {
    final tasks = <TaskItem>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final todoMatch =
          RegExp(r'^\s*[-*+]\s*\[\s*([x\s])\s*\]\s+(.+)$').firstMatch(line);
      if (todoMatch != null) {
        final isCompleted = todoMatch.group(1) == 'x';
        final text = todoMatch.group(2)!.trim();
        tasks.add(TaskItem(
          text: text,
          isCompleted: isCompleted,
        ));
      }
    }
    return tasks;
  }

  /// Parse notes from markdown content (excluding events, tasks, headers)
  static List<String> parseNotes(String content) {
    final notes = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        continue;
      }
      if (RegExp(r'@\d{1,2}:\d{2}').hasMatch(trimmedLine)) {
        continue;
      }
      if (RegExp(r'^\s*[-*+]\s*\[\s*[x\s]\s*\]\s+').hasMatch(trimmedLine)) {
        continue;
      }
      if (trimmedLine.startsWith('#')) {
        continue;
      }

      // Handle bullet points that are not tasks
      if (RegExp(r'^\s*[-*+]\s+').hasMatch(trimmedLine)) {
        final cleanLine =
            trimmedLine.replaceAll(RegExp(r'^\s*[-*+]\s+'), '').trim();
        if (cleanLine.isNotEmpty) {
          notes.add(cleanLine);
        }
        continue;
      }
      notes.add(trimmedLine);
    }
    return notes;
  }

  /// Parse events from markdown content
  static List<CalendarEvent> parseEvents(String date, String content) {
    final events = <CalendarEvent>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final timeMatch = RegExp(r'@(\d{1,2}):(\d{2})').firstMatch(line);

      if (timeMatch != null) {
        try {
          final hour = int.parse(timeMatch.group(1)!);
          final minute = int.parse(timeMatch.group(2)!);

          // Parse date from YYYYMMDD format
          final year = int.parse(date.substring(0, 4));
          final month = int.parse(date.substring(4, 6));
          final day = int.parse(date.substring(6, 8));

          final eventTime = DateTime(year, month, day, hour, minute);
          final title = line.replaceAll(RegExp(r'@\d{1,2}:\d{2}'), '').trim();
          final description = _extractEventDescription(lines, i);

          events.add(CalendarEvent(
            title: title,
            time: eventTime,
            description: description,
            date: date,
          ));
        } catch (e) {
          Log.e('MarkdownParser: Error parsing event line: $line', error: e);
        }
      }
    }

    return events;
  }

  static String _extractEventDescription(
      List<String> lines, int eventLineIndex) {
    final description = StringBuffer();

    // Look for description in the next few lines
    for (int i = eventLineIndex + 1;
        i < lines.length && i < eventLineIndex + 5;
        i++) {
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
}

class TaskItem {
  final String text;
  final bool isCompleted;

  TaskItem({required this.text, required this.isCompleted});
}
