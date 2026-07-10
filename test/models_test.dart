import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/models/calendar_event.dart';
import 'package:planova/models/note_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('DailyFile Model', () {
    test('should create DailyFile with all fields', () {
      final dailyFile = DailyFile(
        path: '/test/path.md',
        date: '20240101',
        content: 'Test content',
      );

      expect(dailyFile.path, equals('/test/path.md'));
      expect(dailyFile.date, equals('20240101'));
      expect(dailyFile.content, equals('Test content'));
    });

    test('should parse date correctly from YYYYMMDD format', () {
      final dailyFile = DailyFile(
        path: '/test/path.md',
        date: '20240101',
        content: 'Test content',
      );

      expect(dailyFile.dateTime.year, equals(2024));
      expect(dailyFile.dateTime.month, equals(1));
      expect(dailyFile.dateTime.day, equals(1));
    });

    test('should format date correctly', () {
      final dailyFile = DailyFile(
        path: '/test/path.md',
        date: '20240101',
        content: 'Test content',
      );

      expect(dailyFile.formattedDate, equals('1/1/2024'));
    });

    test('copyWith should return new instance with updated fields', () {
      final original = DailyFile(
        path: '/test/path.md',
        date: '20240101',
        content: 'Original content',
      );

      final updated = original.copyWith(content: 'Updated content');

      expect(updated.path, equals('/test/path.md'));
      expect(updated.date, equals('20240101'));
      expect(updated.content, equals('Updated content'));
    });

    test('should handle leap year dates', () {
      final dailyFile = DailyFile(
        path: '/test/path.md',
        date: '20240229',
        content: 'Test content',
      );

      expect(dailyFile.dateTime.year, equals(2024));
      expect(dailyFile.dateTime.month, equals(2));
      expect(dailyFile.dateTime.day, equals(29));
    });
  });

  group('CalendarEvent Model', () {
    test('should create CalendarEvent with all fields', () {
      final event = CalendarEvent(
        title: 'Meeting',
        time: DateTime(2024, 1, 1, 10, 30),
        description: 'Team meeting',
        date: '20240101',
      );

      expect(event.title, equals('Meeting'));
      expect(event.time, equals(DateTime(2024, 1, 1, 10, 30)));
      expect(event.description, equals('Team meeting'));
      expect(event.date, equals('20240101'));
    });

    test('should format time correctly with leading zeros', () {
      final event = CalendarEvent(
        title: 'Meeting',
        time: DateTime(2024, 1, 1, 9, 5),
        description: 'Team meeting',
        date: '20240101',
      );

      expect(event.formattedTime, equals('09:05'));
    });

    test('should format time for midnight', () {
      final event = CalendarEvent(
        title: 'Midnight Meeting',
        time: DateTime(2024, 1, 1, 0, 0),
        description: 'Midnight meeting',
        date: '20240101',
      );

      expect(event.formattedTime, equals('00:00'));
    });

    test('should clean title by removing time pattern', () {
      final event = CalendarEvent(
        title: '@10:30 Meeting',
        time: DateTime(2024, 1, 1, 10, 30),
        description: 'Team meeting',
        date: '20240101',
      );

      expect(event.displayTitle, equals('Meeting'));
    });

    test('should clean title by removing markdown list markers', () {
      final event = CalendarEvent(
        title: '- Meeting',
        time: DateTime(2024, 1, 1, 10, 30),
        description: 'Team meeting',
        date: '20240101',
      );

      expect(event.displayTitle, equals('Meeting'));
    });

    test('copyWith should return new instance with updated fields', () {
      final original = CalendarEvent(
        title: 'Meeting',
        time: DateTime(2024, 1, 1, 10, 30),
        description: 'Team meeting',
        date: '20240101',
      );

      final updated = original.copyWith(title: 'Updated Meeting');

      expect(updated.title, equals('Updated Meeting'));
      expect(updated.time, equals(original.time));
      expect(updated.description, equals(original.description));
    });
  });

  group('NoteFile Model', () {
    test('should create NoteFile with all fields', () {
      final noteFile = NoteFile(
        path: '/test/notes/note.md',
        relativePath: 'notes/note.md',
        content: 'Test content',
        lastModified: DateTime(2024, 1, 1),
      );

      expect(noteFile.path, equals('/test/notes/note.md'));
      expect(noteFile.relativePath, equals('notes/note.md'));
      expect(noteFile.content, equals('Test content'));
      expect(noteFile.lastModified, equals(DateTime(2024, 1, 1)));
    });

    test('should extract fileName from relativePath', () {
      final noteFile = NoteFile(
        path: '/test/notes/work_project.md',
        relativePath: 'notes/work_project.md',
        content: 'Test content',
        lastModified: DateTime(2024, 1, 1),
      );

      expect(noteFile.fileName, equals('work_project'));
    });

    test('should extract folder path for note in folder', () {
      final noteFile = NoteFile(
        path: '/test/notes/subfolder/note.md',
        relativePath: 'notes/subfolder/note.md',
        content: 'Test content',
        lastModified: DateTime(2024, 1, 1),
      );

      expect(noteFile.folderPath, equals('notes/subfolder'));
    });

    test('should return empty folderPath for root level note', () {
      final noteFile = NoteFile(
        path: '/test/notes/note.md',
        relativePath: 'note.md',
        content: 'Test content',
        lastModified: DateTime(2024, 1, 1),
      );

      expect(noteFile.folderPath, equals(''));
    });

    test('should replace underscores with spaces in displayName', () {
      final noteFile = NoteFile(
        path: '/test/notes/work_note.md',
        relativePath: 'notes/work_note.md',
        content: 'Test content',
        lastModified: DateTime(2024, 1, 1),
      );

      expect(noteFile.displayName, equals('work note'));
    });

    test('should replace dashes with spaces in displayName', () {
      final noteFile = NoteFile(
        path: '/test/notes/work-note.md',
        relativePath: 'notes/work-note.md',
        content: 'Test content',
        lastModified: DateTime(2024, 1, 1),
      );

      expect(noteFile.displayName, equals('work note'));
    });

    test('should replace both underscores and dashes in displayName', () {
      final noteFile = NoteFile(
        path: '/test/notes/work_note-name.md',
        relativePath: 'notes/work_note-name.md',
        content: 'Test content',
        lastModified: DateTime(2024, 1, 1),
      );

      expect(noteFile.displayName, equals('work note name'));
    });

    test('copyWith should return new instance with updated fields', () {
      final original = NoteFile(
        path: '/test/notes/note.md',
        relativePath: 'notes/note.md',
        content: 'Original content',
        lastModified: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        content: 'Updated content',
        lastModified: DateTime(2024, 1, 2),
      );

      expect(updated.path, equals('/test/notes/note.md'));
      expect(updated.relativePath, equals('notes/note.md'));
      expect(updated.content, equals('Updated content'));
      expect(updated.lastModified, equals(DateTime(2024, 1, 2)));
    });
  });
}
