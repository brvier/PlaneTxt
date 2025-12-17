import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planova/models/calendar_event.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/providers/event_provider.dart';
import 'package:planova/repositories/daily_repository.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/services/widget_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';
import 'package:provider/provider.dart';

class DailyFileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  late DailyRepository _dailyRepository;

  List<DailyFile> _dailyFiles = [];
  String _selectedDate = '';
  String? _lastWidgetUpdateDate;
  Timer? _widgetUpdateTimer;
  static const Duration _widgetUpdateInterval = Duration(minutes: 30);

  DailyFileProvider() {
    Log.i('🚀 DailyFileProvider: Constructor called');
    _dailyRepository = DailyRepository(_storageService);
  }

  List<DailyFile> get dailyFiles => List.unmodifiable(_dailyFiles);
  String get selectedDate => _selectedDate;

  Future<void> loadDailyFiles() async {
    Log.i('📅 DailyFileProvider: Loading daily files...');
    try {
      _dailyFiles = await _dailyRepository.loadAll();
      Log.i('📅 DailyFileProvider: Loaded ${_dailyFiles.length} daily files');

      // Update widget with today's content
      await _updateWidget();

      notifyListeners();
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error loading daily files', e);
      rethrow;
    }
  }

  Future<void> saveDailyFile(
      BuildContext context, String date, String content) async {
    try {
      Log.d('📅 DailyFileProvider: Saving daily file for $date');
      final dailyFile = await _dailyRepository.create(date, content);

      // Update local list
      final index = _dailyFiles.indexWhere((d) => d.date == date);
      if (index != -1) {
        _dailyFiles[index] = dailyFile;
      } else {
        _dailyFiles.add(dailyFile);
        _dailyFiles.sort((a, b) => b.date.compareTo(a.date));
      }

      // Update widget with today's content
      await _updateWidget();

      // Schedule event notifications
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      await eventProvider.scheduleEventNotifications(date, content);

      Log.d('📅 DailyFileProvider: Saved daily file for $date');
      notifyListeners();
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error saving daily file', e);
      rethrow;
    }
  }

  void setSelectedDate(String date) {
    _selectedDate = date;
    Log.d('📅 DailyFileProvider: Selected date set to $date');
    notifyListeners();
  }

  DailyFile? getDailyFile(String date) {
    try {
      return _dailyFiles.firstWhere((d) => d.date == date);
    } catch (e) {
      Log.d('📅 DailyFileProvider: No daily file found for $date');
      return null;
    }
  }

  String getTodayDate() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    Log.d('📅 DailyFileProvider: Today\'s date is $date');
    return date;
  }

  bool hasUndoneTodos(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    final hasUndone = tasks.any((task) => !task.isCompleted);
    Log.d('📅 DailyFileProvider: Date $date has undone todos: $hasUndone');
    return hasUndone;
  }

  bool hasTodos(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    final hasTodos = tasks.isNotEmpty;
    Log.d('📅 DailyFileProvider: Date $date has todos: $hasTodos');
    return hasTodos;
  }

  int getUndoneTodoCount(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return 0;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    final count = tasks.where((task) => !task.isCompleted).length;
    Log.d('📅 DailyFileProvider: Date $date has $count undone todos');
    return count;
  }

  List<CalendarEvent> getCalendarEvents(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return [];

    final events = MarkdownParser.parseEvents(date, dailyFile.content);
    events.sort((a, b) => a.time.compareTo(b.time));
    Log.d('📅 DailyFileProvider: Found ${events.length} events for $date');
    return events;
  }

  bool hasCalendarEvents(String date) {
    final hasEvents = getCalendarEvents(date).isNotEmpty;
    Log.d('📅 DailyFileProvider: Date $date has events: $hasEvents');
    return hasEvents;
  }

  Future<void> checkDateChangeAndUpdateWidget() async {
    final todayDate = getTodayDate();
    if (_lastWidgetUpdateDate != todayDate) {
      Log.i(
          '📱 DailyFileProvider: Date changed detected (was: $_lastWidgetUpdateDate, now: $todayDate), updating widget');
      await _updateWidget();
    }
  }

  /// Update widget with today's daily file
  Future<void> _updateWidget() async {
    try {
      if (_storageService.orgDirectory == null) {
        Log.d(
            '📱 DailyFileProvider: Skipping widget update - directories not initialized');
        return;
      }

      final todayDate = getTodayDate();

      if (_lastWidgetUpdateDate != todayDate) {
        Log.i(
            '📱 DailyFileProvider: Date changed from $_lastWidgetUpdateDate to $todayDate, updating widget');
        _lastWidgetUpdateDate = todayDate;
      } else {
        Log.d(
            '📱 DailyFileProvider: Updating widget (date unchanged: $todayDate)');
      }

      final todayDailyFile = getDailyFile(todayDate);

      if (todayDailyFile != null) {
        Log.d('📱 DailyFileProvider: Updating widget with daily file content');
        await WidgetService.updateWithDailyFile(todayDailyFile);
      }

      Log.i('📱 DailyFileProvider: Widget updated successfully');
    } catch (e) {
      Log.e('❌ DailyFileProvider: Error updating widget', e);
    }
  }

  void startWidgetUpdateTimer() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = Timer.periodic(_widgetUpdateInterval, (timer) async {
      Log.d('📱 DailyFileProvider: Periodic widget update triggered');
      try {
        await loadDailyFiles();
        Log.d('📱 DailyFileProvider: Periodic widget update completed');
      } catch (e) {
        Log.e('❌ DailyFileProvider: Error in periodic widget update', e);
      }
    });
    Log.i(
        '📱 DailyFileProvider: Started periodic widget update timer (every 30 minutes)');
  }

  @override
  void dispose() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = null;
    Log.i('📅 DailyFileProvider: Disposed');
    super.dispose();
  }
}
