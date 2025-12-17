import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:planova/utils/logger.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Directory? _documentsDirectory;
  Directory? _orgDirectory;
  Directory? _dailiesDirectory;
  Directory? _archivesDirectory;
  Directory? _notesDirectory;

  Directory? get documentsDirectory => _documentsDirectory;
  Directory? get orgDirectory => _orgDirectory;
  Directory? get dailiesDirectory => _dailiesDirectory;
  Directory? get archivesDirectory => _archivesDirectory;
  Directory? get notesDirectory => _notesDirectory;

  /// Initialize directories with optional custom path
  Future<void> initializeDirectories(String? customPath) async {
    Log.i('📁 StorageService: Initializing directories...');

    try {
      if (customPath != null) {
        Log.d('📁 StorageService: Using custom storage path: $customPath');
        final customDir = Directory(customPath);
        if (await customDir.exists()) {
          // Test write permissions
          if (await _isWritable(customDir)) {
            _orgDirectory = customDir;
          } else {
            Log.e('❌ StorageService: Custom storage path is not writable');
            await _useDefaultDirectory();
          }
        } else {
          Log.e('❌ StorageService: Custom storage path does not exist');
          await _useDefaultDirectory();
        }
      } else {
        await _useDefaultDirectory();
      }

      _dailiesDirectory = Directory('${_orgDirectory!.path}/dailies');
      _archivesDirectory = Directory('${_orgDirectory!.path}/archives');
      _notesDirectory = Directory('${_orgDirectory!.path}/notes');

      await _createDirectories();
      Log.i('📁 StorageService: Directory initialization completed');
    } catch (e) {
      Log.e('❌ StorageService: Error initializing directories', e);
      // Fallback to default
      await _useDefaultDirectory();
      _dailiesDirectory = Directory('${_orgDirectory!.path}/dailies');
      _archivesDirectory = Directory('${_orgDirectory!.path}/archives');
      _notesDirectory = Directory('${_orgDirectory!.path}/notes');
      await _createDirectories();
    }
  }

  Future<void> _useDefaultDirectory() async {
    Log.d('📁 StorageService: Using default documents directory');
    _documentsDirectory = await getApplicationDocumentsDirectory();
    _orgDirectory = Directory('${_documentsDirectory!.path}/Org');
  }

  Future<bool> _isWritable(Directory dir) async {
    try {
      final testFile = File('${dir.path}/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _createDirectories() async {
    await _orgDirectory!.create(recursive: true);
    await _dailiesDirectory!.create(recursive: true);
    await _archivesDirectory!.create(recursive: true);
    await _notesDirectory!.create(recursive: true);
  }

  /// List files in a directory with specific extension
  List<File> listFiles(Directory dir,
      {String extension = '.md', bool recursive = false}) {
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: recursive)
        .where((entity) => entity is File && entity.path.endsWith(extension))
        .cast<File>()
        .toList();
  }

  /// Read file content
  Future<String> readFile(File file) async {
    try {
      if (!file.existsSync()) return '';
      return await file.readAsString();
    } catch (e) {
      Log.e('❌ StorageService: Error reading file ${file.path}', e);
      return '';
    }
  }

  /// Write content to file
  Future<void> writeFile(File file, String content) async {
    try {
      await file.writeAsString(content);
      Log.d('💾 StorageService: Saved file ${file.path}');
    } catch (e) {
      Log.e('❌ StorageService: Error writing file ${file.path}', e);
      rethrow;
    }
  }

  /// Delete file
  Future<void> deleteFile(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
        Log.d('🗑️ StorageService: Deleted file ${file.path}');
      }
    } catch (e) {
      Log.e('❌ StorageService: Error deleting file ${file.path}', e);
      rethrow;
    }
  }
}
