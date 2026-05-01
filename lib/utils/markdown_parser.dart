import 'package:planova/models/calendar_event.dart';
import 'package:planova/utils/logger.dart';

/// Single source of truth for the regular expressions used to recognise
/// task and event lines in daily markdown. Keeping these as `static final`
/// avoids re-compiling the patterns on every parse and also keeps the
/// recognition rules consistent across the parser, the content helpers,
/// and the notification service.
class MarkdownParser {
  /// Matches the shape of a todo line (with or without text after `]`).
  /// Used for "is this line part of the tasks section" detection.
  static final RegExp todoLine =
      RegExp(r'^\s*[-*+]\s*\[\s*[x\s]\s*\]');

  /// Matches a todo line that has text. Group 1 is the checkbox content
  /// (`x` or whitespace), group 2 is the task text.
  static final RegExp _todoLineWithText =
      RegExp(r'^\s*[-*+]\s*\[\s*([x\s])\s*\]\s+(.+)$');

  /// Matches an event line: bullet followed by `@HH:MM` (24h).
  /// Group 1 is hours (1-2 digits), group 2 is minutes (2 digits).
  static final RegExp eventLine =
      RegExp(r'^\s*[-*+]\s*@(\d{1,2}):(\d{2})\b\s*(.*)$');

  /// Matches any header (level 1-6).
  static final RegExp headerLine = RegExp(r'^\s*#{1,6}\s+');

  /// Matches a non-task bullet line (used by parseNotes).
  static final RegExp _bulletLine = RegExp(r'^\s*[-*+]\s+');

  /// True if [line] is a markdown todo (checked or unchecked).
  static bool isTodoLine(String line) => todoLine.hasMatch(line);

  /// True if [line] is an event line — a bullet followed by `@HH:MM`.
  static bool isEventLine(String line) => eventLine.hasMatch(line);

  /// Parse tasks from markdown content.
  static List<TaskItem> parseTasks(String content) {
    final tasks = <TaskItem>[];
    for (final line in content.split('\n')) {
      final m = _todoLineWithText.firstMatch(line);
      if (m == null) continue;
      tasks.add(TaskItem(
        text: m.group(2)!.trim(),
        isCompleted: m.group(1) == 'x',
      ));
    }
    return tasks;
  }

  /// Parse "free text" notes from markdown — everything that isn't a task,
  /// an event, or a header. Bullet markers are stripped.
  static List<String> parseNotes(String content) {
    final notes = <String>[];
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (headerLine.hasMatch(trimmed)) continue;
      if (isTodoLine(trimmed)) continue;
      if (isEventLine(trimmed)) continue;

      if (_bulletLine.hasMatch(trimmed)) {
        final clean = trimmed.replaceFirst(_bulletLine, '').trim();
        if (clean.isNotEmpty) notes.add(clean);
        continue;
      }
      notes.add(trimmed);
    }
    return notes;
  }

  /// Parse events from markdown content. Only lines shaped like
  /// `- @HH:MM <title>` (with bullet) are considered events; a stray
  /// `@9:00` mention inside a note or description is ignored.
  static List<CalendarEvent> parseEvents(String date, String content) {
    final events = <CalendarEvent>[];
    final lines = content.split('\n');

    int year, month, day;
    try {
      year = int.parse(date.substring(0, 4));
      month = int.parse(date.substring(4, 6));
      day = int.parse(date.substring(6, 8));
    } catch (e) {
      Log.e('MarkdownParser: invalid date "$date"', error: e);
      return events;
    }

    for (var i = 0; i < lines.length; i++) {
      final m = eventLine.firstMatch(lines[i]);
      if (m == null) continue;

      try {
        final hour = int.parse(m.group(1)!);
        final minute = int.parse(m.group(2)!);
        final title = m.group(3)!.trim();
        events.add(CalendarEvent(
          title: title,
          time: DateTime(year, month, day, hour, minute),
          description: _extractEventDescription(lines, i),
          date: date,
        ));
      } catch (e) {
        Log.e('MarkdownParser: error parsing event "${lines[i]}"', error: e);
      }
    }
    return events;
  }

  /// Collect description lines that follow an event line.
  /// Stops at: empty line, another event, a task, or after 4 lines.
  static String _extractEventDescription(List<String> lines, int eventIdx) {
    final buf = StringBuffer();
    final maxLook = (eventIdx + 5).clamp(0, lines.length);
    for (var i = eventIdx + 1; i < maxLook; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) break;
      if (isEventLine(line) || isTodoLine(line)) break;
      if (buf.isNotEmpty) buf.write('\n');
      buf.write(line);
    }
    return buf.toString();
  }
}

class TaskItem {
  final String text;
  final bool isCompleted;

  TaskItem({required this.text, required this.isCompleted});
}
