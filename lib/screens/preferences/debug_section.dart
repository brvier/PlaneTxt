import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:planetxt/screens/widget_debug_screen.dart';
import 'package:planetxt/services/notification_service.dart';
import 'package:planetxt/services/widget_service.dart';
import 'package:planetxt/services/storage_service.dart';

class WidgetHealthTile extends StatelessWidget {
  const WidgetHealthTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.verified_user),
      title: const Text('Check Widget Permissions'),
      subtitle: const Text('Storage and exact alarm access'),
      trailing: const Icon(Icons.refresh),
      onTap: () => _checkWidgetHealth(context),
    );
  }

  Future<void> _checkWidgetHealth(BuildContext context) async {
    if (!context.mounted) return;

    final results = <String>[];

    final storageService = StorageService();
    results.add(storageService.isInitialized
        ? '✓ Storage root: ${storageService.storageDescription}'
        : '⚠ Storage not initialized');
    if (storageService.storageAccessLost) {
      results.add('⚠ Lost access to configured storage folder');
    }

    String exactAlarmStatus = '✓ Exact alarms not required (pre-Android 12)';
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        final allowed = await WidgetService.canScheduleExactAlarms();
        exactAlarmStatus = allowed
            ? '✓ Exact alarms allowed'
            : '⚠ Exact alarms denied — open Settings to allow';
      }
    }
    results.add(exactAlarmStatus);
    results.add('ℹ Boot completed permission is install-time only');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Widget Health'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in results)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (Platform.isAndroid)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                WidgetService.openAlarmPermissionSettings();
              },
              child: const Text('Alarm Settings'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }
}

class DebugToolsTiles extends StatelessWidget {
  const DebugToolsTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Widget Debug'),
          subtitle: const Text('Test widget functionality'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WidgetDebugScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active),
          title: const Text('Test Immediate Notification'),
          subtitle: const Text('Fire a notification right now'),
          onTap: () => _testNotification(
              context,
              () => NotificationService().showTestNotification(),
              'Immediate notification fired! Check your status bar.'),
        ),
        ListTile(
          leading: const Icon(Icons.schedule_send),
          title: const Text('Test Scheduled Notification'),
          subtitle:
              const Text('Tests 3 AlarmManager modes at 15s, 30s, 45s'),
          onTap: () => _testNotification(
              context,
              () => NotificationService().showScheduledTestNotification(),
              '3 tests scheduled: alarmClock@15s, exact@30s, inexact@45s'),
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Test Timer Notification'),
          subtitle:
              const Text('Bypasses AlarmManager, uses Dart Timer (10s)'),
          onTap: () => _testNotification(
              context,
              () => NotificationService().showTimerTestNotification(),
              'Timer set for 10s. Keep app open! (bypasses AlarmManager)'),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Notification Diagnostics'),
          subtitle: const Text('Check notification system status'),
          onTap: () => _showNotificationDiagnostics(context),
        ),
      ],
    );
  }

  Future<void> _testNotification(
      BuildContext context, Future<void> Function() test, String message) async {
    try {
      await test();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showNotificationDiagnostics(BuildContext context) async {
    try {
      final diagnostics = await NotificationService().getDiagnostics();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Notification Diagnostics'),
            content: SingleChildScrollView(
              child: Text(diagnostics,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
