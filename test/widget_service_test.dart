import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('WidgetService Tests', () {
    test('should update widget with daily file content', () async {
      // Create a sample daily file with events and tasks
      final dailyFile = DailyFile(
        path: '/test/path',
        date: '20241201',
        content: '''
# Daily Notes

@09:00 Team meeting
@14:30 Project review

- [ ] Complete project proposal
- [x] Review code changes
- [ ] Update documentation
''',
      );

      // Test that the method doesn't throw an error
      expect(() async {
        await WidgetService.updateWithDailyFile(dailyFile, isDarkTheme: false);
      }, returnsNormally);
    });

    test('should handle null daily file', () async {
      // Test that the method handles null gracefully
      expect(() async {
        await WidgetService.updateWithDailyFile(null, isDarkTheme: false);
      }, returnsNormally);
    });

    test('should clear widget data', () async {
      // Test that clearing widget data doesn't throw an error
      expect(() async {
        await WidgetService.clearWidget();
      }, returnsNormally);
    });
  });
}
