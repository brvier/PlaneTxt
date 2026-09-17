import 'package:flutter_test/flutter_test.dart';
import 'package:planetxt/utils/markdown_parser.dart';

void main() {
  group('MarkdownParser.parseTasks', () {
    test('parses unchecked and checked todos', () {
      const content = '''
# Tasks
- [ ] buy milk
- [x] call mom
* [ ] star bullet
+ [x] plus bullet
''';
      final tasks = MarkdownParser.parseTasks(content);
      expect(tasks.length, 4);
      expect(tasks[0].text, 'buy milk');
      expect(tasks[0].isCompleted, isFalse);
      expect(tasks[1].text, 'call mom');
      expect(tasks[1].isCompleted, isTrue);
      expect(tasks[2].isCompleted, isFalse);
      expect(tasks[3].isCompleted, isTrue);
    });

    test('tolerates indentation and spaces inside brackets', () {
      const content = '  - [ x ] indented done\n\t- [  ] tab todo';
      final tasks = MarkdownParser.parseTasks(content);
      expect(tasks.length, 2);
      expect(tasks[0].isCompleted, isTrue);
      expect(tasks[1].isCompleted, isFalse);
    });

    test('ignores non-todo lines and empty checkboxes without text', () {
      const content = '''
just a note
- a bullet
- [ ]
# header
''';
      expect(MarkdownParser.parseTasks(content), isEmpty);
    });

    test('returns empty list for empty content', () {
      expect(MarkdownParser.parseTasks(''), isEmpty);
    });
  });

  group('MarkdownParser.parseEvents', () {
    test('parses event lines with @HH:MM', () {
      const content = '''
## Events
- @09:30 standup meeting
- @14:05 dentist
''';
      final events = MarkdownParser.parseEvents('20260710', content);
      expect(events.length, 2);
      expect(events[0].title, 'standup meeting');
      expect(events[0].time, DateTime(2026, 7, 10, 9, 30));
      expect(events[1].time, DateTime(2026, 7, 10, 14, 5));
    });

    test('accepts single-digit hour', () {
      final events =
          MarkdownParser.parseEvents('20260710', '- @9:00 breakfast');
      expect(events.length, 1);
      expect(events[0].time.hour, 9);
    });

    test('ignores @time mentions without a bullet', () {
      final events = MarkdownParser.parseEvents(
          '20260710', 'meet me at @9:00 tomorrow');
      expect(events, isEmpty);
    });

    test('collects following lines as description, stopping at blank/todo',
        () {
      const content = '''
- @10:00 review
  bring the notes
  room 4B

- @11:00 next
''';
      final events = MarkdownParser.parseEvents('20260710', content);
      expect(events.length, 2);
      expect(events[0].description, 'bring the notes\nroom 4B');
      expect(events[1].description, isEmpty);
    });

    test('returns empty list for an invalid date string', () {
      expect(MarkdownParser.parseEvents('not-a-date', '- @10:00 x'), isEmpty);
    });
  });

  group('MarkdownParser.parseNotes', () {
    test('keeps free text and plain bullets, strips markers', () {
      const content = '''
# Header
- [ ] a todo
- @10:00 an event
- plain bullet note
free text line
''';
      final notes = MarkdownParser.parseNotes(content);
      expect(notes, ['plain bullet note', 'free text line']);
    });
  });

  group('line classifiers', () {
    test('isTodoLine', () {
      expect(MarkdownParser.isTodoLine('- [ ] x'), isTrue);
      expect(MarkdownParser.isTodoLine('- [x] x'), isTrue);
      expect(MarkdownParser.isTodoLine('- x'), isFalse);
    });

    test('isEventLine', () {
      expect(MarkdownParser.isEventLine('- @10:00 x'), isTrue);
      expect(MarkdownParser.isEventLine('- 10:00 x'), isFalse);
      expect(MarkdownParser.isEventLine('@10:00 x'), isFalse);
    });
  });
}
