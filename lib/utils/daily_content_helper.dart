import 'package:planetxt/utils/logger.dart';
import 'package:planetxt/utils/markdown_parser.dart';

/// Bounds of a markdown section: the index of its `## Header` line and the
/// index just past the section's last line.
class _SectionRange {
  final int headerIndex;
  final int endExclusive; // points past last line of the section
  const _SectionRange(this.headerIndex, this.endExclusive);

  bool get found => headerIndex >= 0;
}

/// Utility functions for working with daily file content.
class DailyContentHelper {
  // ---- shared helpers ------------------------------------------------------

  static String _appendAtEnd(String content, String newContent) {
    if (content.isEmpty) return newContent;
    return content.endsWith('\n')
        ? '$content$newContent'
        : '$content\n\n$newContent';
  }

  /// Find the section identified by the first line matching [headerRegex].
  ///
  /// If [strictItemPredicate] is provided, the section ends at the first
  /// non-empty, non-header line that does not match the predicate (this is
  /// how task/event sections are bounded — a stray note ends the section).
  /// Otherwise the section runs until the next header (or end of file).
  static _SectionRange _findSection(
    List<String> lines,
    RegExp headerRegex, {
    bool Function(String trimmedLine)? strictItemPredicate,
  }) {
    int? headerIndex;
    for (var i = 0; i < lines.length; i++) {
      if (headerRegex.hasMatch(lines[i])) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == null) return const _SectionRange(-1, -1);

    var end = headerIndex + 1;
    while (end < lines.length) {
      final t = lines[end].trim();
      if (t.isEmpty) {
        end++;
        continue;
      }
      if (t.startsWith('#')) break;
      if (strictItemPredicate != null && !strictItemPredicate(t)) break;
      end++;
    }
    return _SectionRange(headerIndex, end);
  }

  static bool _isEventLine(String line) => MarkdownParser.isEventLine(line);
  static bool _isTodoLine(String line) => MarkdownParser.isTodoLine(line);

  // ---- public API ----------------------------------------------------------

  /// Inserts content after the first header matching [headerRegex].
  /// If no matching header is found, appends the content to the end.
  static String insertAfterHeader(
    String content,
    String newContent,
    String headerRegex,
  ) {
    if (headerRegex.isEmpty) return _appendAtEnd(content, newContent);

    try {
      final regex = RegExp(headerRegex, multiLine: true);
      final lines = content.split('\n');

      int? headerIndex;
      for (var i = 0; i < lines.length; i++) {
        if (regex.hasMatch(lines[i])) {
          headerIndex = i;
          break;
        }
      }
      if (headerIndex == null) return _appendAtEnd(content, newContent);

      var insertIndex = headerIndex + 1;
      while (insertIndex < lines.length && lines[insertIndex].trim().isEmpty) {
        insertIndex++;
      }

      final beforeInsert = lines.sublist(0, insertIndex).join('\n');
      final afterInsert = lines.sublist(insertIndex).join('\n');
      final nextLine = afterInsert.split('\n').firstOrNull?.trim() ?? '';
      final nextIsHeader = nextLine.startsWith('#');

      if (afterInsert.isNotEmpty) {
        return nextIsHeader
            ? '$beforeInsert\n$newContent\n\n$afterInsert'
            : '$beforeInsert\n$newContent\n$afterInsert';
      }
      return '$beforeInsert\n$newContent';
    } catch (e) {
      Log.e('DailyContentHelper: invalid regex "$headerRegex"', error: e);
      return _appendAtEnd(content, newContent);
    }
  }

  /// Inserts events into the events section in chronological order, creating
  /// the section at the end of the file if needed. Existing duplicate events
  /// (same time + title) are preserved; new ones are merged in.
  static String insertEventsChronologically(
    String content,
    List<String> eventLines,
    String eventHeaderRegex,
  ) {
    try {
      final regex = RegExp(eventHeaderRegex, multiLine: true);
      final lines = content.split('\n');
      final range =
          _findSection(lines, regex, strictItemPredicate: _isEventLine);
      final sortedNew = _sortEventLinesChronologically(eventLines);

      if (range.found) {
        final beforeEvents = lines.sublist(0, range.headerIndex + 1);
        final eventsBlock =
            lines.sublist(range.headerIndex + 1, range.endExclusive);
        final afterEventsSection = lines.sublist(range.endExclusive);

        final existingEvents =
            eventsBlock.where((l) => _isEventLine(l.trim())).toList();
        final newOnly = sortedNew.where((newE) => !existingEvents.any((e) =>
            _eventsAreSame(e.trim(), newE)));
        // Existing events must be re-inserted alongside the new ones —
        // they were stripped from eventsBlock above.
        final merged = _sortEventLinesChronologically(
            [...existingEvents, ...newOnly]);

        return [
          ...beforeEvents,
          ...eventsBlock.where((l) => !_isEventLine(l.trim())),
          ...merged,
          if (afterEventsSection.isNotEmpty) ...afterEventsSection,
        ].join('\n');
      }
      // No section header found — append a fresh block at the end.
      return _appendAtEnd(content, sortedNew.join('\n'));
    } catch (e) {
      Log.e('DailyContentHelper: error inserting events chronologically',
          error: e);
      return _appendAtEnd(content, eventLines.join('\n'));
    }
  }

  /// Sort event lines chronologically by their `@HH:MM` time.
  static List<String> _sortEventLinesChronologically(List<String> eventLines) {
    final withTimes = eventLines.map((line) {
      final m = MarkdownParser.eventLine.firstMatch(line);
      final t = m == null
          ? 0
          : int.parse(m.group(1)!) * 100 + int.parse(m.group(2)!);
      return MapEntry(t, line);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return withTimes.map((e) => e.value).toList();
  }

  /// Two event lines are considered the same if their text after the time
  /// matches.
  static bool _eventsAreSame(String existing, String newEvent) {
    final stripTime = RegExp(r'^\s*[-*+]\s*@\d{1,2}:\d{2}\s*');
    return existing.replaceFirst(stripTime, '').trim() ==
        newEvent.replaceFirst(stripTime, '').trim();
  }

  /// Inserts an event after the last existing event in the events section.
  /// If the section exists but is empty, inserts right after the header with
  /// a blank-line separator. If the section doesn't exist, appends to end.
  static String insertAfterLastEvent(
    String content,
    String eventContent,
    String eventHeaderRegex,
  ) {
    if (eventHeaderRegex.isEmpty) return _appendAtEnd(content, eventContent);

    try {
      final regex = RegExp(eventHeaderRegex, multiLine: true);
      final lines = content.split('\n');
      final range =
          _findSection(lines, regex, strictItemPredicate: _isEventLine);
      if (!range.found) return _appendAtEnd(content, eventContent);

      return _insertItem(
        lines: lines,
        range: range,
        newItem: eventContent,
        itemMatcher: _isEventLine,
      );
    } catch (e) {
      Log.e('DailyContentHelper: error inserting event after last event',
          error: e);
      return _appendAtEnd(content, eventContent);
    }
  }

  /// Inserts a todo after the last existing todo in the tasks section.
  /// If the section exists but is empty, inserts right after the header
  /// with a blank-line separator. If the section doesn't exist, appends.
  static String insertAfterLastTodo(
    String content,
    String todoContent,
    String todoHeaderRegex,
  ) {
    if (todoHeaderRegex.isEmpty) return _appendAtEnd(content, todoContent);

    try {
      final regex = RegExp(todoHeaderRegex, multiLine: true);
      final lines = content.split('\n');
      final range =
          _findSection(lines, regex, strictItemPredicate: _isTodoLine);
      if (!range.found) return _appendAtEnd(content, todoContent);

      return _insertItem(
        lines: lines,
        range: range,
        newItem: todoContent,
        itemMatcher: _isTodoLine,
      );
    } catch (e) {
      Log.e('DailyContentHelper: error inserting todo after last todo',
          error: e);
      return _appendAtEnd(content, todoContent);
    }
  }

  /// Insert [newItem] after the last line in [range] that matches
  /// [itemMatcher]. If no items exist in the section yet, insert after the
  /// header with a blank-line separator before any subsequent content.
  static String _insertItem({
    required List<String> lines,
    required _SectionRange range,
    required String newItem,
    required bool Function(String line) itemMatcher,
  }) {
    var lastItemIndex = range.headerIndex;
    var hasItems = false;
    for (var i = range.headerIndex + 1; i < range.endExclusive; i++) {
      if (itemMatcher(lines[i])) {
        lastItemIndex = i;
        hasItems = true;
      }
    }

    if (hasItems) {
      final before = lines.sublist(0, lastItemIndex + 1).join('\n');
      final after = lines.sublist(lastItemIndex + 1).join('\n');
      return after.isNotEmpty ? '$before\n$newItem\n$after' : '$before\n$newItem';
    }

    // No items yet — insert right after the header with appropriate spacing.
    final before = lines.sublist(0, range.headerIndex + 1).join('\n');
    final after = lines.sublist(range.headerIndex + 1).join('\n');
    return after.isNotEmpty
        ? '$before\n$newItem\n\n$after'
        : '$before\n\n$newItem';
  }

  /// Inserts content at the end of a section (just before the next `#`
  /// header). If no matching section exists, appends to the end of the file.
  static String insertAtEndOfSection(
    String content,
    String newContent,
    String sectionHeaderRegex,
  ) {
    if (sectionHeaderRegex.isEmpty) return _appendAtEnd(content, newContent);

    try {
      final regex = RegExp(sectionHeaderRegex, multiLine: true);
      final lines = content.split('\n');
      // No item predicate: walk until the next header/EOF, regardless of
      // line shape.
      final range = _findSection(lines, regex);
      if (!range.found) return _appendAtEnd(content, newContent);

      // Walk back from sectionEnd to find the last non-empty line.
      var lastContentIndex = range.endExclusive - 1;
      while (lastContentIndex > range.headerIndex &&
          lines[lastContentIndex].trim().isEmpty) {
        lastContentIndex--;
      }

      final insertIndex = lastContentIndex + 1;
      final before = lines.sublist(0, insertIndex).join('\n');
      final after = lines.sublist(insertIndex).join('\n');
      return after.isNotEmpty ? '$before\n$newContent\n$after' : '$before\n$newContent';
    } catch (e) {
      Log.e('DailyContentHelper: error inserting at end of section', error: e);
      return _appendAtEnd(content, newContent);
    }
  }
}
