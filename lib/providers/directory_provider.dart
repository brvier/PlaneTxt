import 'dart:io';

import 'package:flutter/material.dart';
import 'package:planova/providers/theme_provider.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';
import 'package:provider/provider.dart';

class DirectoryProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  bool _initialized = false;

  DirectoryProvider();

  Directory? get documentsDirectory => _storageService.documentsDirectory;
  Directory? get orgDirectory => _storageService.orgDirectory;
  Directory? get dailiesDirectory => _storageService.dailiesDirectory;
  Directory? get archivesDirectory => _storageService.archivesDirectory;
  Directory? get notesDirectory => _storageService.notesDirectory;

  bool get isInitialized => _initialized;

  Future<void> initializeDirectories(BuildContext context) async {
    Log.i('📁 DirectoryProvider: Initializing directories...');

    try {
      // Get custom storage path from ThemeProvider
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final customPath = themeProvider.customStoragePath;

      await _storageService.initializeDirectories(customPath);

      _initialized = true;
      Log.i(
          '📁 DirectoryProvider: Directory initialization completed successfully');
      notifyListeners();
    } catch (e) {
      Log.e('❌ DirectoryProvider: Error initializing directories', e);
      _initialized = false;
      rethrow;
    }
  }

  String getCurrentStoragePath() {
    final path = _storageService.orgDirectory?.path ?? 'Not initialized';
    Log.d(
        '📁 DirectoryProvider: getCurrentStoragePath() called, returning: $path');
    return path;
  }

  @override
  void dispose() {
    Log.i('📁 DirectoryProvider: Disposed');
    super.dispose();
  }
}
