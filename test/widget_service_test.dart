import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel homeWidgetChannel = MethodChannel('home_widget');
  final List<MethodCall> homeWidgetCalls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    homeWidgetCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async {
      homeWidgetCalls.add(call);

      switch (call.method) {
        case 'saveWidgetData':
        case 'updateWidget':
        case 'setAppGroupId':
          return true;
        case 'getWidgetData':
          return null;
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
  });

  group('WidgetService', () {
    test('updateWithDailyFile writes widget keys and triggers update',
        () async {
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

      await WidgetService.updateWithDailyFile(dailyFile, isDarkTheme: false);

      // Plugin calls
      expect(
        homeWidgetCalls.where((c) => c.method == 'saveWidgetData').length,
        greaterThanOrEqualTo(2),
      );
      expect(
        homeWidgetCalls.any((c) => c.method == 'updateWidget'),
        isTrue,
      );

      // Also ensure the data is in prefs (used by widget access).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_daily_content'), isNotEmpty);
      expect(prefs.getString('widget_date'), equals('20241201'));
      expect(prefs.getBool('flutter.widget_dark_theme'), isFalse);
    });

    test('updateWithDailyFile with null does nothing', () async {
      await WidgetService.updateWithDailyFile(null, isDarkTheme: false);
      expect(homeWidgetCalls, isEmpty);
    });

    test('clearWidget removes prefs and triggers update', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_daily_content', 'content');
      await prefs.setString('widget_date', '20241201');

      await WidgetService.clearWidget();

      expect(prefs.getString('widget_daily_content'), isNull);
      expect(prefs.getString('widget_date'), isNull);
      expect(homeWidgetCalls.any((c) => c.method == 'updateWidget'), isTrue);
    });
  });
}
