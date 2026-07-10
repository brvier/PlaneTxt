import 'package:flutter_test/flutter_test.dart';
import 'package:planova/utils/daily_content_helper.dart';

const todoHeader = r'^#{1,2}\s+.*Tasks?';
const eventHeader = r'^#{1,2}\s+.*Events?';

void main() {
  group('DailyContentHelper.insertAfterLastTodo', () {
    test('inserts after the last todo in the section', () {
      const content = '''
## Tasks
- [ ] first
- [x] second

## Notes
something''';
      final result = DailyContentHelper.insertAfterLastTodo(
          content, '- [ ] third', todoHeader);
      final lines = result.split('\n');
      final idx = lines.indexOf('- [ ] third');
      expect(idx, greaterThan(lines.indexOf('- [x] second')));
      expect(idx, lessThan(lines.indexOf('## Notes')));
    });

    test('inserts right after the header when the section is empty', () {
      const content = '''
## Tasks

## Notes''';
      final result = DailyContentHelper.insertAfterLastTodo(
          content, '- [ ] new', todoHeader);
      final lines = result.split('\n');
      expect(lines[lines.indexOf('## Tasks') + 1], '- [ ] new');
    });

    test('appends at end when no header matches', () {
      final result = DailyContentHelper.insertAfterLastTodo(
          'just text', '- [ ] new', todoHeader);
      expect(result.trim().endsWith('- [ ] new'), isTrue);
    });

    test('appends at end when regex is empty', () {
      final result =
          DailyContentHelper.insertAfterLastTodo('text', '- [ ] new', '');
      expect(result.contains('- [ ] new'), isTrue);
    });
  });

  group('DailyContentHelper.insertAfterLastEvent', () {
    test('inserts after the last event of the section', () {
      const content = '''
## Events
- @09:00 standup

## Tasks''';
      final result = DailyContentHelper.insertAfterLastEvent(
          content, '- @10:00 review', eventHeader);
      final lines = result.split('\n');
      expect(lines.indexOf('- @10:00 review'),
          lines.indexOf('- @09:00 standup') + 1);
    });
  });

  group('DailyContentHelper.insertEventsChronologically', () {
    test('merges new events sorted by time, skipping duplicates', () {
      const content = '''
## Events
- @12:00 lunch
''';
      final result = DailyContentHelper.insertEventsChronologically(
        content,
        ['- @15:00 coffee', '- @08:00 gym', '- @12:00 lunch'],
        eventHeader,
      );
      final lines =
          result.split('\n').where((l) => l.startsWith('- @')).toList();
      // Existing events are preserved first, new ones merged in time order;
      // the duplicate lunch is not added twice.
      expect(lines.where((l) => l.contains('lunch')).length, 1);
      expect(lines.indexWhere((l) => l.contains('gym')),
          lessThan(lines.indexWhere((l) => l.contains('coffee'))));
    });

    test('appends a fresh block when no events section exists', () {
      final result = DailyContentHelper.insertEventsChronologically(
          'notes only', ['- @08:00 gym'], eventHeader);
      expect(result.contains('- @08:00 gym'), isTrue);
    });
  });

  group('DailyContentHelper.insertAtEndOfSection', () {
    test('inserts before the next header', () {
      const content = '''
## Log
first entry

## Notes
note''';
      final result = DailyContentHelper.insertAtEndOfSection(
          content, '- 10:00 did things', r'^#{1,2}\s+.*Log');
      final lines = result.split('\n');
      expect(lines.indexOf('- 10:00 did things'),
          lines.indexOf('first entry') + 1);
    });
  });

  group('DailyContentHelper.insertAfterHeader', () {
    test('inserts right after the matching header', () {
      const content = '''
## Tasks
- [ ] existing''';
      final result = DailyContentHelper.insertAfterHeader(
          content, '- [ ] new', todoHeader);
      final lines = result.split('\n');
      expect(lines[lines.indexOf('## Tasks') + 1], '- [ ] new');
    });

    test('falls back to append on invalid regex', () {
      final result =
          DailyContentHelper.insertAfterHeader('text', 'new', r'([');
      expect(result.contains('new'), isTrue);
    });
  });
}
