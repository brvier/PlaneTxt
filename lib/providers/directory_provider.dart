import 'package:flutter/material.dart';
import 'package:planetxt/providers/theme_provider.dart';
import 'package:planetxt/services/storage_service.dart';
import 'package:planetxt/utils/logger.dart';
import 'package:provider/provider.dart';

class DirectoryProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  bool _initialized = false;

  DirectoryProvider();

  bool get isInitialized => _initialized;

  /// True when the configured storage root (SAF tree or custom path) could
  /// not be accessed and the app fell back to the default private folder.
  /// The UI should prompt the user to re-select their folder.
  bool get storageAccessLost => _storageService.storageAccessLost;

  Future<void> initializeDirectories(BuildContext context) async {
    Log.i('📁 DirectoryProvider: Initializing storage...');

    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      await _storageService.initializeDirectories(
        customPath: themeProvider.customStoragePath,
        safTreeUri: themeProvider.storageTreeUri,
        safDisplayName: themeProvider.storageTreeName,
      );

      _initialized = true;
      Log.i('📁 DirectoryProvider: Storage initialization completed');
      notifyListeners();
    } catch (e) {
      Log.e('❌ DirectoryProvider: Error initializing storage', error: e);
      _initialized = false;
      rethrow;
    }
  }

  String getCurrentStoragePath() => _storageService.storageDescription;

  @override
  void dispose() {
    Log.i('📁 DirectoryProvider: Disposed');
    super.dispose();
  }
}
