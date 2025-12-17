import 'package:flutter/material.dart';
import 'package:planova/providers/directory_provider.dart';
import 'package:planova/providers/daily_file_provider.dart';
import 'package:planova/providers/event_provider.dart';
import 'package:planova/providers/note_file_provider.dart';
import 'package:planova/providers/theme_provider.dart';
import 'package:planova/screens/main_screen.dart';
import 'package:planova/services/notification_service.dart';
import 'package:planova/services/widget_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize widget service
  await WidgetService.initialize();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  
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
          if (!themeProvider.isInitialized) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              debugShowCheckedModeBanner: false,
            );
          }
          
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