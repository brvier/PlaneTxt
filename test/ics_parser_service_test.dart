import 'package:flutter_test/flutter_test.dart';
import 'package:planetxt/services/ics_parser_service.dart';

const _calendarHeader = 'BEGIN:VCALENDAR\nVERSION:2.0\n';
const _calendarFooter = 'END:VCALENDAR\n';

String _wrap(String vevents) => '$_calendarHeader$vevents$_calendarFooter';

void main() {
  group('IcsParserService.parseIcsContent', () {
    test('parses a simple local-time event', () {
      final ics = _wrap('''
BEGIN:VEVENT
DTSTART:20261225T103000
SUMMARY:Christmas brunch
DESCRIPTION:Bring gifts
END:VEVENT
''');
      final events = IcsParserService.parseIcsContent(ics);
      expect(events.length, 1);
      expect(events[0].title, 'Christmas brunch');
      expect(events[0].description, 'Bring gifts');
      expect(events[0].time, DateTime(2026, 12, 25, 10, 30));
      expect(events[0].date, '20261225');
    });

    test('converts UTC timestamps (Z suffix) to local time', () {
      final ics = _wrap('''
BEGIN:VEVENT
DTSTART:20261225T100000Z
SUMMARY:UTC event
END:VEVENT
''');
      final events = IcsParserService.parseIcsContent(ics);
      expect(events.length, 1);
      expect(events[0].time, DateTime.utc(2026, 12, 25, 10, 0).toLocal());
    });

    test('date-only DTSTART defaults to 09:00', () {
      final ics = _wrap('''
BEGIN:VEVENT
DTSTART:20261225
SUMMARY:All day
END:VEVENT
''');
      final events = IcsParserService.parseIcsContent(ics);
      expect(events.length, 1);
      expect(events[0].time, DateTime(2026, 12, 25, 9, 0));
    });

    test('handles property parameters like DTSTART;TZID=...', () {
      final ics = _wrap('''
BEGIN:VEVENT
DTSTART;TZID=Europe/Paris:20261225T103000
SUMMARY:With TZID
END:VEVENT
''');
      final events = IcsParserService.parseIcsContent(ics);
      expect(events.length, 1);
      expect(events[0].title, 'With TZID');
    });

    test('skips VEVENTs missing DTSTART or SUMMARY', () {
      final ics = _wrap('''
BEGIN:VEVENT
SUMMARY:No date
END:VEVENT
BEGIN:VEVENT
DTSTART:20261225T103000
END:VEVENT
''');
      expect(IcsParserService.parseIcsContent(ics), isEmpty);
    });

    test('parses multiple VEVENTs and survives one malformed block', () {
      final ics = _wrap('''
BEGIN:VEVENT
DTSTART:20261225T090000
SUMMARY:First
END:VEVENT
BEGIN:VEVENT
DTSTART:garbage
SUMMARY:Broken
END:VEVENT
BEGIN:VEVENT
DTSTART:20261226T090000
SUMMARY:Second
END:VEVENT
''');
      final events = IcsParserService.parseIcsContent(ics);
      expect(events.map((e) => e.title), ['First', 'Second']);
    });

    test('handles CRLF line endings', () {
      final ics = _wrap('BEGIN:VEVENT\r\n'
          'DTSTART:20261225T103000\r\n'
          'SUMMARY:CRLF event\r\n'
          'END:VEVENT\r\n');
      final events = IcsParserService.parseIcsContent(ics);
      expect(events.length, 1);
      expect(events[0].title, 'CRLF event');
    });
  });

  group('IcsParserService.isValidIcsContent', () {
    test('accepts a minimal valid calendar', () {
      expect(IcsParserService.isValidIcsContent(_wrap('')), isTrue);
    });

    test('rejects empty and non-ICS content', () {
      expect(IcsParserService.isValidIcsContent(''), isFalse);
      expect(IcsParserService.isValidIcsContent('hello world'), isFalse);
      expect(
          IcsParserService.isValidIcsContent(
              'BEGIN:VCALENDAR\nEND:VCALENDAR'),
          isFalse); // missing VERSION
    });
  });
}
