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
            Log.e('❌ StorageService: Custom storage path is not writable',
                error: 'Permission denied');
            await _useDefaultDirectory();
          }
        } else {
          Log.e('❌ StorageService: Custom storage path does not exist',
              error: 'Path not found');
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
      Log.e('❌ StorageService: Error initializing directories', error: e);
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

  /// Async variant of [listFiles] — doesn't block the UI isolate on
  /// directory I/O.
  Future<List<File>> listFilesAsync(Directory dir,
      {String extension = '.md', bool recursive = false}) async {
    if (!await dir.exists()) return [];
    return dir
        .list(recursive: recursive)
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
      Log.e('❌ StorageService: Error reading file ${file.path}', error: e);
      return '';
    }
  }

  /// Write content to file
  Future<void> writeFile(File file, String content) async {
    try {
      await file.writeAsString(content);
      Log.d('💾 StorageService: Saved file ${file.path}');
    } catch (e) {
      Log.e('❌ StorageService: Error writing file ${file.path}', error: e);
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
      Log.e('❌ StorageService: Error deleting file ${file.path}', error: e);
      rethrow;
    }
  }

  /// Get file modification time safely
  DateTime? getFileModifiedTime(File file) {
    try {
      if (file.existsSync()) {
        return file.lastModifiedSync();
      }
      return null;
    } catch (e) {
      Log.e(
          '❌ StorageService: Error getting modification time for ${file.path}',
          error: e);
      return null;
    }
  }

  /// Check if file exists and get basic info
  Future<FileInfo?> getFileInfo(File file) async {
    try {
      if (!file.existsSync()) {
        return null;
      }

      final stat = await file.stat();
      return FileInfo(
        path: file.path,
        size: stat.size,
        modified: stat.modified,
        accessed: stat.accessed,
        type: stat.type,
      );
    } catch (e) {
      Log.e('❌ StorageService: Error getting file info for ${file.path}',
          error: e);
      return null;
    }
  }

  /// Get directory info including file count
  Future<DirectoryInfo?> getDirectoryInfo(Directory dir) async {
    try {
      if (!dir.existsSync()) {
        return null;
      }

      final entities = await dir.list().toList();
      int fileCount = 0;
      int dirCount = 0;
      int totalSize = 0;

      for (final entity in entities) {
        if (entity is File) {
          fileCount++;
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            Log.w('⚠️ StorageService: Could not get size for ${entity.path}');
          }
        } else if (entity is Directory) {
          dirCount++;
        }
      }

      return DirectoryInfo(
        path: dir.path,
        fileCount: fileCount,
        directoryCount: dirCount,
        totalSize: totalSize,
      );
    } catch (e) {
      Log.e('❌ StorageService: Error getting directory info for ${dir.path}',
          error: e);
      return null;
    }
  }

  /// Batch file operations for better performance
  Future<BatchOperationResult> batchWrite(
      List<FileOperation> operations) async {
    final result = BatchOperationResult(
      successful: [],
      failed: [],
    );

    Log.d(
        '💾 StorageService: Starting batch write operation with ${operations.length} files');

    final stopwatch = Stopwatch()..start();

    try {
      // Process operations in parallel batches to avoid overwhelming the system
      const batchSize = 10;
      for (int i = 0; i < operations.length; i += batchSize) {
        final batch = operations.skip(i).take(batchSize).toList();

        final futures = batch.map((op) => _performFileOperation(op));
        final batchResults = await Future.wait(futures);

        for (final batchResult in batchResults) {
          if (batchResult.success) {
            result.successful.add(batchResult.operation!);
          } else {
            result.failed.add(FileOperationFailure(
              operation: batchResult.operation!,
              error: batchResult.error ?? 'Unknown error',
            ));
          }
        }
      }

      stopwatch.stop();
      Log.i(
          '💾 StorageService: Batch operation completed in ${stopwatch.elapsedMilliseconds}ms - ${result.successful.length} successful, ${result.failed.length} failed');

      return result;
    } catch (e) {
      Log.e('❌ StorageService: Error in batch write operation', error: e);

      // Add all operations as failed
      result.failed.addAll(operations.map((op) => FileOperationFailure(
            operation: op,
            error: e.toString(),
          )));

      return result;
    }
  }

  Future<OperationResult> _performFileOperation(FileOperation operation) async {
    try {
      final file = File(operation.path);

      switch (operation.type) {
        case FileOperationType.write:
          await file.writeAsString(operation.content ?? '');
          break;
        case FileOperationType.delete:
          if (file.existsSync()) {
            await file.delete();
          }
          break;
        case FileOperationType.append:
          await file.writeAsString(operation.content ?? '',
              mode: FileMode.append);
          break;
      }

      return OperationResult.success(operation);
    } catch (e) {
      Log.e(
          '❌ StorageService: Error performing file operation ${operation.type} on ${operation.path}',
          error: e);
      return OperationResult.failure(operation, e.toString());
    }
  }
}

/// File information class
class FileInfo {
  final String path;
  final int size;
  final DateTime modified;
  final DateTime accessed;
  final FileSystemEntityType type;

  FileInfo({
    required this.path,
    required this.size,
    required this.modified,
    required this.accessed,
    required this.type,
  });
}

/// Directory information class
class DirectoryInfo {
  final String path;
  final int fileCount;
  final int directoryCount;
  final int totalSize;

  DirectoryInfo({
    required this.path,
    required this.fileCount,
    required this.directoryCount,
    required this.totalSize,
  });
}

/// File operation for batch processing
class FileOperation {
  final String path;
  final FileOperationType type;
  final String? content;

  FileOperation({
    required this.path,
    required this.type,
    this.content,
  });

  FileOperation.write(String path, String content)
      : this(path: path, type: FileOperationType.write, content: content);

  FileOperation.append(String path, String content)
      : this(path: path, type: FileOperationType.append, content: content);

  FileOperation.delete(String path)
      : this(path: path, type: FileOperationType.delete);
}

/// File operation type
enum FileOperationType {
  write,
  append,
  delete,
}

/// Batch operation result
class BatchOperationResult {
  final List<FileOperation> successful;
  final List<FileOperationFailure> failed;

  BatchOperationResult({
    required this.successful,
    required this.failed,
  });
}

/// File operation failure
class FileOperationFailure {
  final FileOperation operation;
  final String error;

  FileOperationFailure({
    required this.operation,
    required this.error,
  });
}

/// Individual operation result
class OperationResult {
  final FileOperation? operation;
  final bool success;
  final String? error;

  OperationResult._({this.operation, required this.success, this.error});

  factory OperationResult.success(FileOperation operation) {
    return OperationResult._(operation: operation, success: true);
  }

  factory OperationResult.failure(FileOperation operation, String error) {
    return OperationResult._(
        operation: operation, success: false, error: error);
  }
}
