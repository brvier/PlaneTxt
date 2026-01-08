import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/models/note_file.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';

class NoteRepository {
  final StorageService _storageService;
  final List<NoteFile> _cache = [];
  final Map<String, DateTime> _lastModified = {};

  NoteRepository(this._storageService);

  /// Load all note files with parallel processing and incremental cache
  Future<List<NoteFile>> loadAll({bool forceReload = false}) async {
    Log.d(
        '📝 NoteRepository: Loading all note files (forceReload: $forceReload)...');

    final dir = _storageService.notesDirectory;
    if (dir == null) {
      Log.e('❌ NoteRepository: Notes directory not initialized');
      return [];
    }

    final files = _storageService.listFiles(dir, recursive: true);

    if (forceReload) {
      _cache.clear();
      _lastModified.clear();
    }

    // Determine which files need loading
    final filesToLoad = <File>[];
    final cachedFiles = <NoteFile>[];

    for (final file in files) {
      try {
        final relativePath =
            path.relative(file.path, from: dir.path).replaceAll('\\', '/');
        final currentModified = file.lastModifiedSync();

        // Find cached version by relative path
        final cachedIndex =
            _cache.indexWhere((n) => n.relativePath == relativePath);
        final cached = cachedIndex != -1 ? _cache[cachedIndex] : null;

        if (cached != null &&
            _lastModified[relativePath] != null &&
            !_lastModified[relativePath]!.isBefore(currentModified) &&
            !forceReload) {
          // File hasn't changed, use cached version
          cachedFiles.add(cached.copyWith(
            path: file.path, // Update path in case it changed
            lastModified: currentModified,
          ));
        } else {
          // File is new or modified, needs loading
          filesToLoad.add(file);
          _lastModified[relativePath] = currentModified;
        }
      } catch (e) {
        Log.e(
            '❌ NoteRepository: Error checking file modification time ${file.path}',
            error: e);
        filesToLoad.add(file);
      }
    }

    // Remove cached files that no longer exist
    final existingRelativePaths = files
        .map((f) => path.relative(f.path, from: dir.path).replaceAll('\\', '/'))
        .toSet();

    _cache.removeWhere(
        (note) => !existingRelativePaths.contains(note.relativePath));
    _lastModified.removeWhere(
        (relativePath, _) => !existingRelativePaths.contains(relativePath));

    // Parallel load files that need updating
    final loadedFiles = await _loadFilesParallel(filesToLoad, dir.path);

    // Update cache with newly loaded files
    for (final noteFile in loadedFiles) {
      // Remove existing entry with same relative path if exists
      _cache.removeWhere((n) => n.relativePath == noteFile.relativePath);
      _cache.add(noteFile);
    }

    // Combine cached and newly loaded files
    final allFiles = [...cachedFiles, ...loadedFiles];

    // Sort by last modified descending
    allFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    Log.i(
        '📝 NoteRepository: Loaded ${allFiles.length} note files (${cachedFiles.length} from cache, ${loadedFiles.length} newly loaded)');
    return allFiles;
  }

  /// Load multiple files in parallel for better performance
  Future<List<NoteFile>> _loadFilesParallel(
      List<File> files, String basePath) async {
    if (files.isEmpty) return [];

    Log.d('📝 NoteRepository: Loading ${files.length} files in parallel...');
    final stopwatch = Stopwatch()..start();

    try {
      final futures = files.map((file) => _loadSingleFile(file, basePath));
      final results = await Future.wait(futures);

      // Filter out null results (failed loads)
      final loadedFiles = results.whereType<NoteFile>().toList();

      stopwatch.stop();
      Log.d(
          '📝 NoteRepository: Parallel loading completed in ${stopwatch.elapsedMilliseconds}ms');

      return loadedFiles;
    } catch (e) {
      Log.e('❌ NoteRepository: Error in parallel file loading', error: e);

      // Fallback to sequential loading if parallel fails
      Log.w('📝 NoteRepository: Falling back to sequential loading');
      return await _loadFilesSequential(files, basePath);
    }
  }

  /// Load files sequentially as fallback
  Future<List<NoteFile>> _loadFilesSequential(
      List<File> files, String basePath) async {
    final loadedFiles = <NoteFile>[];

    for (final file in files) {
      try {
        final noteFile = await _loadSingleFile(file, basePath);
        if (noteFile != null) {
          loadedFiles.add(noteFile);
        }
      } catch (e) {
        Log.e('❌ NoteRepository: Error loading note file ${file.path}',
            error: e);
      }
    }

    return loadedFiles;
  }

  /// Load a single note file
  Future<NoteFile?> _loadSingleFile(File file, String basePath) async {
    try {
      final content = await _storageService.readFile(file);
      final relativePath =
          path.relative(file.path, from: basePath).replaceAll('\\', '/');
      final lastModified = file.lastModifiedSync();

      return NoteFile(
        path: file.path,
        relativePath: relativePath,
        content: content,
        lastModified: lastModified,
      );
    } catch (e) {
      Log.e('❌ NoteRepository: Error loading note file ${file.path}', error: e);
      return null;
    }
  }

  /// Incremental update - only load files modified since last load
  Future<List<NoteFile>> loadIncremental() async {
    Log.d('📝 NoteRepository: Loading incremental changes...');

    final dir = _storageService.notesDirectory;
    if (dir == null) {
      Log.e('❌ NoteRepository: Notes directory not initialized');
      return List.from(_cache)
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    }

    final files = _storageService.listFiles(dir, recursive: true);
    final modifiedFiles = <File>[];

    // Check for modified files
    for (final file in files) {
      try {
        final relativePath =
            path.relative(file.path, from: dir.path).replaceAll('\\', '/');
        final currentModified = file.lastModifiedSync();

        if (_lastModified[relativePath] == null ||
            _lastModified[relativePath]!.isBefore(currentModified)) {
          modifiedFiles.add(file);
          _lastModified[relativePath] = currentModified;
        }
      } catch (e) {
        Log.e('❌ NoteRepository: Error checking file ${file.path}', error: e);
      }
    }

    // Remove deleted files from cache
    final existingRelativePaths = files
        .map((f) => path.relative(f.path, from: dir.path).replaceAll('\\', '/'))
        .toSet();

    _cache.removeWhere(
        (note) => !existingRelativePaths.contains(note.relativePath));
    _lastModified.removeWhere(
        (relativePath, _) => !existingRelativePaths.contains(relativePath));

    // Load modified files in parallel
    final loadedFiles = await _loadFilesParallel(modifiedFiles, dir.path);

    // Update cache
    for (final noteFile in loadedFiles) {
      // Remove existing entry with same relative path if exists
      _cache.removeWhere((n) => n.relativePath == noteFile.relativePath);
      _cache.add(noteFile);
    }

    final allFiles = <NoteFile>[..._cache]
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

    Log.i(
        '📝 NoteRepository: Incremental load completed - ${loadedFiles.length} files updated, ${allFiles.length} total');
    return allFiles;
  }

  /// Get cached notes
  List<NoteFile> get cachedNotes => List.unmodifiable(_cache);

  /// Get cached files count
  int get cacheSize => _cache.length;

  /// Clear cache manually
  void clearCache() {
    _cache.clear();
    _lastModified.clear();
    Log.d('📝 NoteRepository: Cache cleared');
  }

  /// Save note file
  Future<void> save(NoteFile noteFile) async {
    try {
      final file = File(noteFile.path);
      await _storageService.writeFile(file, noteFile.content);

      // Update cache
      final index = _cache.indexWhere((n) => n.path == noteFile.path);
      if (index != -1) {
        _cache[index] = noteFile.copyWith(lastModified: DateTime.now());
      } else {
        _cache.add(noteFile.copyWith(lastModified: DateTime.now()));
      }

      // Re-sort
      _cache.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      Log.d('📝 NoteRepository: Saved note file ${noteFile.relativePath}');
    } catch (e) {
      Log.e('❌ NoteRepository: Error saving note file', error: e);
      rethrow;
    }
  }

  String _sanitizeRelativePath(String relativePath) {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Note path cannot be empty');
    }

    // Normalize to forward slashes to make it consistent across platforms.
    final normalized = path.posix.normalize(trimmed.replaceAll('\\', '/'));

    if (path.posix.isAbsolute(normalized)) {
      throw ArgumentError('Note path must be relative');
    }

    final segments =
        path.posix.split(normalized).where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.any((s) => s == '.' || s == '..')) {
      throw ArgumentError('Invalid note path');
    }

    var sanitized = path.posix.joinAll(segments);
    if (!sanitized.endsWith('.md')) {
      sanitized = '$sanitized.md';
    }

    return sanitized;
  }

  /// Create new note file
  Future<NoteFile> create(String relativePath, String content) async {
    final dir = _storageService.notesDirectory;
    if (dir == null) {
      throw Exception('Notes directory not initialized');
    }

    final sanitizedRelativePath = _sanitizeRelativePath(relativePath);
    final filePath = path.normalize(path.join(dir.path, sanitizedRelativePath));

    if (!path.isWithin(dir.path, filePath)) {
      throw ArgumentError('Note path escapes notes directory');
    }

    final file = File(filePath);

    // Ensure parent directory exists
    await file.parent.create(recursive: true);

    final noteFile = NoteFile(
      path: filePath,
      relativePath: sanitizedRelativePath,
      content: content,
      lastModified: DateTime.now(),
    );

    await save(noteFile);
    return noteFile;
  }

  /// Delete note file
  Future<void> delete(NoteFile noteFile) async {
    try {
      final file = File(noteFile.path);
      await _storageService.deleteFile(file);
      _cache.removeWhere((n) => n.path == noteFile.path);
      Log.d('📝 NoteRepository: Deleted note file ${noteFile.relativePath}');
    } catch (e) {
      Log.e('❌ NoteRepository: Error deleting note file', error: e);
      rethrow;
    }
  }
}
