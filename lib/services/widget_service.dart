import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:planova/constants/app_constants.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/models/note_file.dart';
import 'package:planova/themes/app_themes.dart';
import 'package:planova/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class WidgetService {
  static const String _widgetName = 'PlanovaWidget';
  static const String _dailyContentKey = 'widget_daily_content';
  static const String _notesContentKey = 'widget_notes_content';
  static const String _dateKey = 'widget_date';

  static const String _alarmPermissionChannel = 'planova/alarm_permission';

  static AppTheme _resolveAppTheme(SharedPreferences prefs) {
    final rawIndex =
        prefs.getInt(AppConstants.appThemeKey) ?? AppTheme.gruvbox.index;
    if (rawIndex < 0 || rawIndex >= AppTheme.values.length) {
      return AppTheme.gruvbox;
    }
    return AppTheme.values[rawIndex];
  }

  static ThemeData _resolveWidgetThemeData(
    SharedPreferences prefs, {
    bool? isDarkThemeOverride,
  }) {
    final appTheme = _resolveAppTheme(prefs);
    final isDark = isDarkThemeOverride ??
        prefs.getBool(AppConstants.widgetThemeKey) ??
        false;

    final themeData = AppThemes.getTheme(appTheme);
    return isDark ? themeData.darkTheme : themeData.lightTheme;
  }

  static Future<void> _saveWidgetColors(
    SharedPreferences prefs, {
    bool? isDarkThemeOverride,
  }) async {
    final theme = _resolveWidgetThemeData(
      prefs,
      isDarkThemeOverride: isDarkThemeOverride,
    );

    final backgroundColor =
        theme.colorScheme.surfaceContainerHighest.toARGB32();
    final titleColor = theme.colorScheme.primary.toARGB32();
    final textColor = theme.colorScheme.onSurface.toARGB32();

    await prefs.setInt(AppConstants.widgetBackgroundColorKey, backgroundColor);
    await prefs.setInt(AppConstants.widgetTitleColorKey, titleColor);
    await prefs.setInt(AppConstants.widgetTextColorKey, textColor);

    await HomeWidget.saveWidgetData<int>(
      AppConstants.widgetBackgroundColorKey,
      backgroundColor,
    );
    await HomeWidget.saveWidgetData<int>(
      AppConstants.widgetTitleColorKey,
      titleColor,
    );
    await HomeWidget.saveWidgetData<int>(
      AppConstants.widgetTextColorKey,
      textColor,
    );
  }

  static Future<void> updateWidgetColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveWidgetColors(prefs);

      await HomeWidget.saveWidgetData(
        'widget_colors_updated',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );

      Log.i('📱 WidgetService: Updated widget colors');
    } catch (e) {
      Log.e('❌ WidgetService: Error updating widget colors', error: e);
    }
  }

  /// Initialize the widget service
  static Future<void> initialize() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await HomeWidget.setAppGroupId('group.fr.rvier.planova');
      }
      Log.i('📱 WidgetService: Initialized successfully');
    } catch (e) {
      Log.e('❌ WidgetService: Error initializing', error: e);
    }
  }

  /// Check if exact alarms are allowed (Android 12+). Returns true on other platforms.
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      final methodChannel = const MethodChannel(_alarmPermissionChannel);
      final result =
          await methodChannel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (e) {
      Log.w('⚠️ WidgetService: canScheduleExactAlarms failed, assuming allowed',
          error: e);
      return true;
    }
  }

  /// Open exact alarm permission settings (Android 12+)
  static Future<void> openAlarmPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final methodChannel = const MethodChannel(_alarmPermissionChannel);
      await methodChannel.invokeMethod('openAlarmPermissionSettings');
    } catch (e) {
      Log.e('❌ WidgetService: Failed to open alarm permission settings',
          error: e);
    }
  }

  /// Update widget with today's daily file content
  static Future<void> updateWithDailyFile(DailyFile? dailyFile,
      {bool? isDarkTheme, double? transparency}) async {
    if (dailyFile == null) return;

    try {
      // Use raw markdown content for widget
      final content = dailyFile.content;

      // Format content for widget with daily view style
      final widgetContent = _formatDailyContentWithMarkdown(content);

      // Save to SharedPreferences for widget access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dailyContentKey, widgetContent);
      await prefs.setString(_dateKey, dailyFile.date);

      // Save theme preference if provided
      if (isDarkTheme != null) {
        await prefs.setBool(AppConstants.widgetThemeKey, isDarkTheme);
        await HomeWidget.saveWidgetData<bool>(
          AppConstants.widgetThemeKey,
          isDarkTheme,
        );
        Log.d('📱 WidgetService: Saved widget theme preference: $isDarkTheme');
      }

      // Save transparency preference if provided
      if (transparency != null) {
        await prefs.setDouble(AppConstants.widgetTransparencyKey, transparency);
        await HomeWidget.saveWidgetData<double>(
          AppConstants.widgetTransparencyKey,
          transparency,
        );
        Log.d(
            '📱 WidgetService: Saved widget transparency preference: $transparency');
      }

      await _saveWidgetColors(
        prefs,
        isDarkThemeOverride: isDarkTheme,
      );

      // Update widget
      await HomeWidget.saveWidgetData<String>(_dailyContentKey, widgetContent);
      await HomeWidget.saveWidgetData<String>(_dateKey, dailyFile.date);
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );

      Log.i(
          '📱 WidgetService: Updated widget with daily content for ${dailyFile.date}');
    } catch (e) {
      Log.e('❌ WidgetService: Error updating widget with daily file', error: e);
    }
  }

  /// Update widget with recent notes
  static Future<void> updateWithNotes(List<NoteFile> notes,
      {bool? isDarkTheme, double? transparency}) async {
    try {
      // Get the 3 most recent notes
      final recentNotes = notes.take(3).toList();

      // Format notes for widget with raw markdown
      final widgetContent = _formatNotesWithMarkdown(recentNotes);

      // Save to SharedPreferences for widget access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notesContentKey, widgetContent);

      // Save theme preference if provided
      if (isDarkTheme != null) {
        await prefs.setBool(AppConstants.widgetThemeKey, isDarkTheme);
        await HomeWidget.saveWidgetData<bool>(
          AppConstants.widgetThemeKey,
          isDarkTheme,
        );
      }

      // Save transparency preference if provided
      if (transparency != null) {
        await prefs.setDouble(AppConstants.widgetTransparencyKey, transparency);
        await HomeWidget.saveWidgetData<double>(
          AppConstants.widgetTransparencyKey,
          transparency,
        );
      }

      await _saveWidgetColors(
        prefs,
        isDarkThemeOverride: isDarkTheme,
      );

      // Update widget
      await HomeWidget.saveWidgetData<String>(_notesContentKey, widgetContent);
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );

      Log.i(
          '📱 WidgetService: Updated widget with ${recentNotes.length} recent notes');
    } catch (e) {
      Log.e('❌ WidgetService: Error updating widget with notes', error: e);
    }
  }

  /// Extract todos from daily content
  static List<String> _extractTodos(String content) {
    final lines = content.split('\n');
    final todos = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      final todoMatch =
          RegExp(r'^-\s*\[\s*([x\s])\s*\]\s+(.+)$').firstMatch(trimmed);
      if (todoMatch != null) {
        final isCompleted = todoMatch.group(1) == 'x';
        final text = todoMatch.group(2)!.trim();
        if (text.isNotEmpty) {
          // Add visual indicator for completion status
          final status = isCompleted ? '✓' : '○';
          todos.add('$status $text');
        }
      }
    }

    return todos.take(5).toList(); // Limit to 5 todos
  }

  /// Extract events from daily content
  static List<String> _extractEvents(String content) {
    final lines = content.split('\n');
    final events = <String>[];

    for (final line in lines) {
      final timeMatch = RegExp(r'@(\d{1,2}):(\d{2})').firstMatch(line);
      if (timeMatch != null) {
        final hour = timeMatch.group(1)!;
        final minute = timeMatch.group(2)!;
        final time = '${hour.padLeft(2, '0')}:$minute';
        final event = line.replaceAll(RegExp(r'@\d{1,2}:\d{2}'), '').trim();
        if (event.isNotEmpty) {
          events.add('$time $event');
        }
      }
    }

    return events.take(3).toList(); // Limit to 3 events
  }

  /// Format daily content with markdown for widget display
  static String _formatDailyContentWithMarkdown(String content) {
    if (content.trim().isEmpty) {
      return 'No content for today';
    }

    // Create structured widget content similar to daily view
    return _createStructuredWidgetContent(content);
  }

  /// Create a more detailed widget content with structured layout
  static String _createStructuredWidgetContent(String content) {
    final events = _extractEvents(content);
    final tasks = _extractTodos(content);

    final buffer = StringBuffer();

    // Events section with icon and styling (similar to daily view)
    if (events.isNotEmpty) {
      buffer.writeln('📅 Events');
      for (final event in events) {
        buffer.writeln('  $event');
      }
      buffer.writeln();
    }

    // Tasks section with icon and styling (similar to daily view)
    if (tasks.isNotEmpty) {
      buffer.writeln('✓ Tasks');
      for (final task in tasks) {
        buffer.writeln('  $task');
      }
    }

    if (buffer.isEmpty) {
      return 'No events or tasks for today';
    }

    return buffer.toString();
  }

  /// Format notes with markdown for widget display
  static String _formatNotesWithMarkdown(List<NoteFile> notes) {
    if (notes.isEmpty) {
      return 'No recent notes';
    }

    final buffer = StringBuffer();

    for (int i = 0; i < notes.length && i < 3; i++) {
      final note = notes[i];
      final displayName = note.displayName;

      if (i > 0) buffer.writeln();
      buffer.writeln('**$displayName**');

      // Get first few lines of content, preserving markdown
      final lines = note.content.split('\n');
      const maxLines = 4;
      for (int j = 0; j < lines.length && j < maxLines; j++) {
        final line = lines[j].trim();
        if (line.isNotEmpty) {
          buffer.writeln(line);
        }
      }

      if (lines.length > maxLines) {
        buffer.writeln('...');
      }
    }

    return buffer.toString();
  }

  /// Update widget theme only
  static Future<void> updateWidgetTheme(bool isDarkTheme) async {
    try {
      // Save theme preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.widgetThemeKey, isDarkTheme);
      await HomeWidget.saveWidgetData<bool>(
        AppConstants.widgetThemeKey,
        isDarkTheme,
      );

      await _saveWidgetColors(
        prefs,
        isDarkThemeOverride: isDarkTheme,
      );

      // Force widget update by updating the widget data
      await HomeWidget.saveWidgetData('widget_theme_updated',
          DateTime.now().millisecondsSinceEpoch.toString());

      // Update widget to refresh with new theme
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );

      Log.i(
          '📱 WidgetService: Updated widget theme to ${isDarkTheme ? 'dark' : 'light'}');
    } catch (e) {
      Log.e('❌ WidgetService: Error updating widget theme', error: e);
    }
  }

  /// Update widget transparency only
  static Future<void> updateWidgetTransparency(double transparency) async {
    try {
      // Save transparency preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(AppConstants.widgetTransparencyKey, transparency);
      await HomeWidget.saveWidgetData<double>(
        AppConstants.widgetTransparencyKey,
        transparency,
      );

      // Force widget update by updating the widget data
      await HomeWidget.saveWidgetData('widget_transparency_updated',
          DateTime.now().millisecondsSinceEpoch.toString());

      // Update widget to refresh with new transparency
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );

      Log.i(
          '📱 WidgetService: Updated widget transparency to ${(transparency * 100).round()}%');
    } catch (e) {
      Log.e('❌ WidgetService: Error updating widget transparency', error: e);
    }
  }

  /// Update widget to show empty state for a given date (no daily file exists)
  static Future<void> updateWidgetEmptyDay(String date) async {
    try {
      const widgetContent = 'No events or tasks for today';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dailyContentKey, widgetContent);
      await prefs.setString(_dateKey, date);

      await _saveWidgetColors(prefs);

      await HomeWidget.saveWidgetData<String>(_dailyContentKey, widgetContent);
      await HomeWidget.saveWidgetData<String>(_dateKey, date);
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );

      Log.i('📱 WidgetService: Updated widget with empty day for $date');
    } catch (e) {
      Log.e('❌ WidgetService: Error updating widget for empty day', error: e);
    }
  }

  /// Clear widget data
  static Future<void> clearWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dailyContentKey);
      await prefs.remove(_notesContentKey);
      await prefs.remove(_dateKey);

      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );

      Log.i('📱 WidgetService: Cleared widget data');
    } catch (e) {
      Log.e('❌ WidgetService: Error clearing widget', error: e);
    }
  }

  /// Test widget functionality
  static Future<bool> testWidget() async {
    try {
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'PlanovaWidgetProvider',
      );
      Log.i('📱 WidgetService: Widget test successful');
      return true;
    } catch (e) {
      Log.e('❌ WidgetService: Widget test failed', error: e);
      return false;
    }
  }

  /// Dispose widget resources
  static Future<void> dispose() async {
    try {
      // Clear widget data
      await clearWidget();
      Log.i('📱 WidgetService: Disposed widget resources');
    } catch (e) {
      Log.e('❌ WidgetService: Error disposing widget', error: e);
    }
  }
}
