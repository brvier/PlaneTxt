import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:planova/constants/app_constants.dart';
import 'package:planova/models/calendar_event.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/models/note_file.dart';
import 'package:planova/providers/theme_provider.dart';
import 'package:planova/repositories/daily_repository.dart';
import 'package:planova/repositories/note_repository.dart';
import 'package:planova/services/file_monitor_service.dart';
import 'package:planova/services/notification_service.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/services/widget_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:planova/utils/markdown_parser.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  late DailyRepository _dailyRepository;
  late NoteRepository _noteRepository;

  List<DailyFile> _dailyFiles = [];
  List<NoteFile> _noteFiles = [];
  String _selectedDate = '';
  String? _lastWidgetUpdateDate;
  Timer? _widgetUpdateTimer;
  static const Duration _widgetUpdateInterval = Duration(minutes: 30);

  FileProvider() {
    Log.i('🚀 FileProvider: Constructor called');
    _dailyRepository = DailyRepository(_storageService);
    _noteRepository = NoteRepository(_storageService);
  }

  Directory? get documentsDirectory => _storageService.documentsDirectory;
  Directory? get orgDirectory => _storageService.orgDirectory;
  Directory? get dailiesDirectory => _storageService.dailiesDirectory;
  Directory? get archivesDirectory => _storageService.archivesDirectory;
  Directory? get notesDirectory => _storageService.notesDirectory;

  List<DailyFile> get dailyFiles => List.unmodifiable(_dailyFiles);
  List<NoteFile> get noteFiles => List.unmodifiable(_noteFiles);
  String get selectedDate => _selectedDate;

  Future<void> initializeDirectories(BuildContext context) async {
    Log.i('📁 FileProvider: Initializing directories...');
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    try {
      await _storageService
          .initializeDirectories(themeProvider.customStoragePath);

      await loadDailyFiles();
      await loadNoteFiles();

      // Initialize file monitoring for external changes
      if (dailiesDirectory != null) {
        await FileMonitorService().initialize(dailiesDirectory!);
      }

      // Update widget with today's content
      await _updateWidget(context);

      // Start periodic widget updates
      _startWidgetUpdateTimer();

      Log.i('📁 FileProvider: Directory initialization completed successfully');
      notifyListeners();
    } catch (e) {
      Log.e('❌ FileProvider: Error initializing directories', error: e);
      // Attempt fallback if not already handled by StorageService
    }
  }

  Future<void> loadDailyFiles({bool forceReload = false}) async {
    _dailyFiles = await _dailyRepository.loadAll(forceReload: forceReload);

    // Update widget with today's content
    await _updateWidget();

    notifyListeners();
  }

  Future<void> loadNoteFiles({bool forceReload = false}) async {
    _noteFiles = await _noteRepository.loadAll(forceReload: forceReload);
    notifyListeners();
  }

  /// Incremental update for daily files - only load modified files
  Future<void> loadDailyFilesIncremental() async {
    _dailyFiles = await _dailyRepository.loadIncremental();

    // Update widget with today's content
    await _updateWidget();

    notifyListeners();
  }

  /// Incremental update for note files - only load modified files
  Future<void> loadNoteFilesIncremental() async {
    _noteFiles = await _noteRepository.loadIncremental();
    notifyListeners();
  }

  /// Refresh both repositories incrementally
  Future<void> refreshIncremental() async {
    Log.d('📁 FileProvider: Performing incremental refresh...');

    await Future.wait([
      loadDailyFilesIncremental(),
      loadNoteFilesIncremental(),
    ]);

    Log.d('📁 FileProvider: Incremental refresh completed');
  }

  Future<void> saveDailyFile(String date, String content) async {
    try {
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

      // Schedule notifications for events
      await _scheduleEventNotifications(date, content);

      notifyListeners();
    } catch (e) {
      Log.e('❌ FileProvider: Error saving daily file', error: e);
    }
  }

  Future<void> saveNoteFile(String relativePath, String content) async {
    try {
      await _noteRepository.create(relativePath, content);

      // Reload notes to ensure correct order and metadata
      await loadNoteFiles();

      // Update widget with recent notes
      await _updateWidget();

      notifyListeners();
    } catch (e) {
      Log.e('❌ FileProvider: Error saving note file', error: e);
    }
  }

  Future<bool> renameNoteFile(NoteFile note, String newName) async {
    // Validate new name
    if (newName.trim().isEmpty) return false;

    // Clean the new name
    final cleanName =
        newName.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    if (cleanName.isEmpty) return false;

    // Create new relative path
    final newRelativePath = note.folderPath.isEmpty
        ? '$cleanName.md'
        : '${note.folderPath}/$cleanName.md';

    try {
      // Check if exists
      final dir = _storageService.notesDirectory;
      if (dir == null) return false;

      final newFile = File('${dir.path}/$newRelativePath');
      if (await newFile.exists()) return false;

      // Perform rename via repository (delete old, create new for now as repository doesn't have rename yet,
      // or implement rename in repository. Let's do manual rename here using StorageService or just file system for now
      // but better to add rename to Repository later. For now, I'll stick to the logic:

      final oldFile = File(note.path);
      await oldFile.rename(newFile.path);

      // Reload notes
      await loadNoteFiles();

      // Update widget
      await _updateWidget();

      return true;
    } catch (e) {
      Log.e('❌ FileProvider: Error renaming note', error: e);
      return false;
    }
  }

  void setSelectedDate(String date) {
    _selectedDate = date;
    notifyListeners();
  }

  DailyFile? getDailyFile(String date) {
    try {
      return _dailyFiles.firstWhere((d) => d.date == date);
    } catch (e) {
      return null;
    }
  }

  String getTodayDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  String getCurrentStoragePath() {
    final path = _storageService.orgDirectory?.path ?? 'Not initialized';
    Log.d('📁 FileProvider: getCurrentStoragePath() called, returning: $path');
    return path;
  }

  bool hasUndoneTodos(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    return tasks.any((task) => !task.isCompleted);
  }

  bool hasTodos(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    return tasks.isNotEmpty;
  }

  int getUndoneTodoCount(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return 0;

    final tasks = MarkdownParser.parseTasks(dailyFile.content);
    return tasks.where((task) => !task.isCompleted).length;
  }

  List<CalendarEvent> getCalendarEvents(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return [];

    final events = MarkdownParser.parseEvents(date, dailyFile.content);
    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  bool hasCalendarEvents(String date) {
    return getCalendarEvents(date).isNotEmpty;
  }

  /// Update widget with today's daily file and recent notes
  Future<void> _updateWidget([BuildContext? context]) async {
    try {
      if (_storageService.orgDirectory == null) {
        Log.d(
            '📱 FileProvider: Skipping widget update - directories not initialized');
        return;
      }

      final todayDate = getTodayDate();

      if (_lastWidgetUpdateDate != todayDate) {
        Log.i(
            '📱 FileProvider: Date changed from $_lastWidgetUpdateDate to $todayDate, updating widget');
        _lastWidgetUpdateDate = todayDate;
      } else {
        Log.d('📱 FileProvider: Updating widget (date unchanged: $todayDate)');
      }

      final todayDailyFile = getDailyFile(todayDate);

      bool isDarkTheme = false;
      double transparency = 1.0;

      if (context != null) {
        try {
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          isDarkTheme = themeProvider.widgetDarkTheme;
          transparency = themeProvider.widgetTransparency;
        } catch (e) {
          Log.w(
              '📱 FileProvider: Could not access ThemeProvider, falling back to SharedPreferences');
          final prefs = await SharedPreferences.getInstance();
          isDarkTheme = prefs.getBool(AppConstants.widgetThemeKey) ?? false;
          transparency =
              prefs.getDouble(AppConstants.widgetTransparencyKey) ?? 1.0;
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        isDarkTheme = prefs.getBool(AppConstants.widgetThemeKey) ?? false;
        transparency =
            prefs.getDouble(AppConstants.widgetTransparencyKey) ?? 1.0;
      }

      Log.d(
          '📱 FileProvider: Updating widget with dark theme: $isDarkTheme, transparency: ${(transparency * 100).round()}%');

      if (todayDailyFile != null) {
        await WidgetService.updateWithDailyFile(todayDailyFile,
            isDarkTheme: isDarkTheme, transparency: transparency);
      }

      await WidgetService.updateWithNotes(_noteFiles,
          isDarkTheme: isDarkTheme, transparency: transparency);

      Log.i('📱 FileProvider: Widget updated successfully');
    } catch (e) {
      Log.e('❌ FileProvider: Error updating widget', error: e);
    }
  }

  Future<void> checkDateChangeAndUpdateWidget([BuildContext? context]) async {
    final todayDate = getTodayDate();
    if (_lastWidgetUpdateDate != todayDate) {
      Log.i(
          '📱 FileProvider: Date changed detected (was: $_lastWidgetUpdateDate, now: $todayDate), updating widget');
      await _updateWidget(context);
    }
  }

  Future<void> _scheduleEventNotifications(String date, String content) async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final events = MarkdownParser.parseEvents(date, content);

      await notificationService.cancelNotificationsForDate(date);

      for (final event in events) {
        final eventId =
            NotificationService.generateEventId(event.displayTitle, event.time);
        await notificationService.scheduleEventNotification(
          id: eventId,
          title: event.displayTitle,
          description: event.description,
          eventDateTime: event.time,
          date: date,
        );
      }

      Log.i('📅 Scheduled ${events.length} event notifications for $date');
    } catch (e) {
      Log.e('❌ Error scheduling event notifications', error: e);
    }
  }

  void _startWidgetUpdateTimer() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = Timer.periodic(_widgetUpdateInterval, (timer) async {
      Log.d('📱 FileProvider: Periodic widget update triggered');
      try {
        // Use incremental loading for better performance
        await refreshIncremental();
        await _updateWidget();
        Log.d('📱 FileProvider: Periodic widget update completed');
      } catch (e) {
        Log.e('❌ FileProvider: Error in periodic widget update', error: e);

        // Fallback to full reload if incremental fails
        try {
          Log.w('📱 FileProvider: Falling back to full reload');
          await Future.wait([
            loadDailyFiles(forceReload: true),
            loadNoteFiles(forceReload: true),
          ]);
          await _updateWidget();
        } catch (fallbackError) {
          Log.e('❌ FileProvider: Even fallback reload failed',
              error: fallbackError);
        }
      }
    });
    Log.i(
        '📱 FileProvider: Started periodic widget update timer (every 30 minutes)');
  }

  @override
  void dispose() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = null;
    WidgetService.dispose();
    FileMonitorService().dispose();
    super.dispose();
  }
}
