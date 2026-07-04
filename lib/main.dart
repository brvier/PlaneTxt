import 'package:flutter/material.dart';
import 'package:planova/providers/directory_provider.dart';
import 'package:planova/providers/daily_file_provider.dart';
import 'package:planova/providers/event_provider.dart';
import 'package:planova/providers/note_file_provider.dart';
import 'package:planova/providers/theme_provider.dart';
import 'package:planova/screens/main_screen.dart';
import 'package:planova/services/shared_prefs_service.dart';
import 'package:planova/services/widget_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize shared preferences (must be first)
  await SharedPrefsService.initialize();

  // Initialize widget service
  await WidgetService.initialize();

  // Notification service init + permission request happen after first
  // frame, in MainScreen's background startup tasks — they must not block
  // first paint.

  runApp(const PlanovaApp());
}

class PlanovaApp extends StatelessWidget {
  const PlanovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DirectoryProvider()),
        ChangeNotifierProvider(create: (_) => DailyFileProvider()),
        ChangeNotifierProvider(create: (_) => NoteFileProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Planova',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
