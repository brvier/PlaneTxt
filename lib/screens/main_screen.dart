import 'package:flutter/material.dart';
import 'package:planova/providers/daily_file_provider.dart';
import 'package:planova/providers/directory_provider.dart';
import 'package:planova/providers/note_file_provider.dart';
import 'package:planova/screens/calendar_view.dart';
import 'package:planova/screens/notes_view.dart';
import 'package:planova/screens/preferences_screen.dart';
import 'package:planova/services/file_monitor_service.dart';
import 'package:planova/services/intent_handler_service.dart';
import 'package:planova/utils/logger.dart';
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
      // Initialize directories first
      Log.i('🚀 MainScreen: Initializing DirectoryProvider...');
      final directoryProvider = context.read<DirectoryProvider>();
      await directoryProvider.initializeDirectories(context);

      // Start monitoring dailies for external changes
      final dailiesDirectory = directoryProvider.dailiesDirectory;
      if (dailiesDirectory != null) {
        await FileMonitorService().initialize(dailiesDirectory);
      } else {
        Log.w(
            '🚀 MainScreen: Dailies directory not initialized; skipping file monitor');
      }

      // Initialize daily files (full load on first startup)
      Log.i('🚀 MainScreen: Loading daily files...');
      await context.read<DailyFileProvider>().loadDailyFiles(forceReload: true);

      // Initialize notes (full load on first startup)
      Log.i('🚀 MainScreen: Loading note files...');
      await context.read<NoteFileProvider>().loadNoteFiles(forceReload: true);

      // Start widget update timers
      context.read<DailyFileProvider>().startWidgetUpdateTimer();
      context.read<NoteFileProvider>().startWidgetUpdateTimer();

      // Handle any shared intents (ICS files, etc.)
      await _handleSharedIntents();

      Log.i('🚀 MainScreen: All providers initialized successfully');
    } catch (e) {
      Log.e('❌ MainScreen: Error initializing providers', error: e);
      rethrow;
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
    try {
      Log.d('📅 MainScreen: Checking for shared intents...');

      // Use IntentHandlerService to process any shared content
      final selectedDate =
          await IntentHandlerService.handleSharedIntent(context);

      if (selectedDate != null) {
        Log.i(
            '📅 MainScreen: Shared intent processed successfully, selected date: $selectedDate');

        // Navigate to the calendar view and select the date
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0.0),
        child: AppBar(),
      ),
      body: _screens[_currentIndex],
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
