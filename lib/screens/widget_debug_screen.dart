import 'package:flutter/material.dart';
import 'package:planetxt/services/widget_service.dart';
import 'package:planetxt/services/shared_prefs_service.dart';

class WidgetDebugScreen extends StatefulWidget {
  const WidgetDebugScreen({super.key});

  @override
  State<WidgetDebugScreen> createState() => _WidgetDebugScreenState();
}

class _WidgetDebugScreenState extends State<WidgetDebugScreen> {
  bool _isLoading = false;
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Debug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _testWidgetInitialization,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Widget Initialization'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testWidgetInitialization() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing widget functionality...\n';
    });

    try {
      // Test widget service initialization
      await WidgetService.initialize();
      _result += '✓ Widget service initialized\n';

      // Test SharedPreferences for widget data
      final prefs = SharedPrefsService.instance;
      final testContent =
          'Test widget content\n📅 Events\n  ◦ Test event\n✓ Tasks\n  ◦ Test task';

      await prefs.setString('widget_daily_content', testContent);
      await prefs.setString(
          'widget_date', DateTime.now().millisecondsSinceEpoch.toString());

      _result += '✓ Test data saved to SharedPreferences\n';

      // Test widget update
      final success = await WidgetService.testWidget();
      if (success) {
        _result += '✓ Widget update test passed\n';
      } else {
        _result += '✗ Widget update test failed\n';
      }

      // Check if data exists in SharedPreferences
      final savedContent = prefs.getString('widget_daily_content');
      final savedDate = prefs.getString('widget_date');

      _result += '\nStored data:\n';
      _result += 'Content: $savedContent\n';
      _result += 'Date: $savedDate\n';
    } catch (e) {
      _result += '\n✗ Error: $e\n';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
