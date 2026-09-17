import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:planetxt/providers/daily_file_provider.dart';
import 'package:planetxt/providers/directory_provider.dart';
import 'package:planetxt/providers/note_file_provider.dart';
import 'package:planetxt/screens/calendar_view.dart';
import 'package:planetxt/screens/notes_view.dart';
import 'package:planetxt/screens/preferences_screen.dart';
import 'package:planetxt/services/file_monitor_service.dart';
import 'package:planetxt/services/intent_handler_service.dart';
import 'package:planetxt/services/notification_service.dart';
import 'package:planetxt/utils/logger.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CalendarView(),
    const NotesView(),
    const PreferencesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // The OS may kill the process while backgrounded; flush the disk
      // caches so the next cold start restores the latest saves.
      unawaited(context.read<DailyFileProvider>().persistCache());
      unawaited(context.read<NoteFileProvider>().persistCache());
    }
    if (state == AppLifecycleState.resumed) {
      // Check if date changed while app was in background
      context.read<DailyFileProvider>().checkDateChangeAndUpdateWidget();

      // Perform incremental refresh to catch any external file changes
      _performIncrementalRefresh().then((_) {
        // Handle any shared intents that came in while app was in background
        _handleSharedIntents();
      });
    }
  }

  /// Perform incremental refresh after a delay to avoid blocking UI
  Future<void> _performIncrementalRefresh() async {
    // Small delay to ensure app is fully resumed
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      Log.d('🚀 MainScreen: Performing incremental refresh on app resume');

      await Future.wait([
        context.read<DailyFileProvider>().loadDailyFilesIncremental(),
        context.read<NoteFileProvider>().loadNoteFilesIncremental(),
      ]);

      Log.d('🚀 MainScreen: Incremental refresh completed');
    } catch (e) {
      Log.e('🚀 MainScreen: Error during incremental refresh', error: e);
    }
  }

  Future<void> _initializeProviders() async {
    Log.i('🚀 MainScreen: Starting provider initialization...');

    try {
      // 1. Directories first - everything else depends on this.
      Log.i('🚀 MainScreen: Initializing DirectoryProvider...');
      final directoryProvider = context.read<DirectoryProvider>();
      await directoryProvider.initializeDirectories(context);

      if (!mounted) return;

      // Access to the configured storage folder was lost (folder deleted,
      // permission revoked, or migration from the pre-SAF custom path).
      // The app fell back to its private folder; tell the user how to get
      // their files back.
      if (directoryProvider.storageAccessLost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Storage folder is no longer accessible. Re-select it in '
                'Preferences → Storage Location to keep using your synced '
                'files.'),
            duration: Duration(seconds: 12),
          ),
        );
      }

      // 2. Today-priority load: disk-cache restore + today refresh. The
      //    calendar can paint with last-known content immediately after.
      Log.i('🚀 MainScreen: Today-priority load...');
      final dailyProvider = context.read<DailyFileProvider>();
      await dailyProvider.loadTodayPriority();

      if (!mounted) return;

      // 3. Everything else - notifications, file monitor, full validation,
      //    notes - runs in the background; no await on the critical path.
      unawaited(_runBackgroundStartupTasks(directoryProvider));

      Log.i('🚀 MainScreen: Critical-path initialization complete');
    } catch (e) {
      Log.e('❌ MainScreen: Error initializing providers', error: e);
      rethrow;
    }
  }

  Future<void> _runBackgroundStartupTasks(
      DirectoryProvider directoryProvider) async {
    try {
      final dailyProvider = context.read<DailyFileProvider>();
      final noteProvider = context.read<NoteFileProvider>();

      // Notification plugin init + permission request - deliberately after
      // first paint (platform channels + possible system dialog).
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.requestPermissions();

      if (!mounted) return;

      // Start file-change monitoring (native events or SAF polling).
      await FileMonitorService().initialize();

      if (!mounted) return;

      // Full mtime sweep + reload of stale daily files.
      Log.i('🚀 MainScreen: Background - full daily file validation...');
      await dailyProvider.loadDailyFiles();

      if (!mounted) return;

      // Schedule notifications for existing events using already-loaded
      // content - avoids a second filesystem-wide scan + read.
      await FileMonitorService()
          .scheduleExistingEvents(dailyFiles: dailyProvider.dailyFiles);

      if (!mounted) return;

      // Notes - user is on the Calendar tab; safe to defer.
      Log.i('🚀 MainScreen: Background - loading note files...');
      await noteProvider.loadNoteFiles();

      if (!mounted) return;

      dailyProvider.startWidgetUpdateTimer();
      noteProvider.startWidgetUpdateTimer();

      // Shared intents (ICS files, etc.)
      await _handleSharedIntents();

      Log.i('🚀 MainScreen: Background initialization complete');
    } catch (e) {
      Log.e('❌ MainScreen: Error in background initialization', error: e);
    }
  }

  /// Navigate to a specific date in the calendar view
  void _navigateToDate(String date) {
    // Switch to calendar view if not already there
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }

    // Set the selected date in the daily file provider
    // This will trigger the calendar view to show the correct date
    context.read<DailyFileProvider>().setSelectedDate(date);
  }

  /// Handle shared intents (ICS files, calendar events, etc.)
  Future<void> _handleSharedIntents() async {
    if (!Platform.isAndroid) {
      Log.d('📅 MainScreen: Skipping intent handling on non-Android platform');
      return;
    }

    try {
      Log.d('📅 MainScreen: Checking for shared intents...');

      // Use IntentHandlerService to process any shared content
      final selectedDate =
          await IntentHandlerService.handleSharedIntent(context);

      if (selectedDate != null) {
        Log.i(
            '📅 MainScreen: Shared intent processed successfully, selected date: $selectedDate');

        // Navigate to calendar view and select the date
        if (selectedDate.isNotEmpty) {
          _navigateToDate(selectedDate);
        }
      } else {
        Log.d('📅 MainScreen: No shared intent data to process');
      }
    } catch (e) {
      Log.e('❌ MainScreen: Error handling shared intents', error: e);
      // Don't rethrow - this shouldn't prevent app from working
    }
  }

  /// Thin banner shown while the app reads every file to build its cache
  /// (first launch, or right after the storage folder changed). The full
  /// scan runs in the background; without this the app just looks slow.
  Widget _buildCacheBanner(BuildContext context) {
    final daily = context.watch<DailyFileProvider>();
    final notes = context.watch<NoteFileProvider>();
    if (!daily.isBuildingCache && !notes.isBuildingCache) {
      return const SizedBox.shrink();
    }

    final done = daily.cacheProgressDone + notes.cacheProgressDone;
    final total = daily.cacheProgressTotal + notes.cacheProgressTotal;
    final label = total > 0
        ? 'Building cache... $done/$total files'
        : 'Building cache...';

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: total > 0 ? done / total : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0.0),
        child: AppBar(),
      ),
      body: Column(
        children: [
          _buildCacheBanner(context),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
