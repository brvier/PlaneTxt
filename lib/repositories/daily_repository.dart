import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/models/daily_file.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';

class DailyRepository {
  final StorageService _storageService;
  final Map<String, DailyFile> _cache = {};
  final Map<String, DateTime> _lastModified = {};

  DailyRepository(this._storageService);

  /// Load all daily files with parallel processing and incremental cache
  Future<List<DailyFile>> loadAll({bool forceReload = false}) async {
    Log.d(
        '📅 DailyRepository: Loading all daily files (forceReload: $forceReload)...');

    final dir = _storageService.dailiesDirectory;
    if (dir == null) {
      Log.e('❌ DailyRepository: Dailies directory not initialized');
      return [];
    }

    final files = _storageService.listFiles(dir);
    final validFiles = <File>[];
    final fileDates = <String, File>{};

    // Filter and categorize files
    for (final file in files) {
      try {
        final fileName = path.basename(file.path);
        final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
        if (dateMatch != null) {
          final date = dateMatch.group(1)!;
          validFiles.add(file);
          fileDates[date] = file;
        }
      } catch (e) {
        Log.e('❌ DailyRepository: Error processing file ${file.path}',
            error: e);
      }
    }

    if (forceReload) {
      _cache.clear();
      _lastModified.clear();
    }

    // Determine which files need loading
    final filesToLoad = <File>[];
    final cachedFiles = <DailyFile>[];

    for (final entry in fileDates.entries) {
      final date = entry.key;
      final file = entry.value;

      try {
        final currentModified = file.lastModifiedSync();
        final cached = _cache[date];

        if (cached != null &&
            _lastModified[date] != null &&
            !_lastModified[date]!.isBefore(currentModified) &&
            !forceReload) {
          // File hasn't changed, use cached version
          cachedFiles.add(cached.copyWith(
            path: file.path, // Update path in case it changed
          ));
        } else {
          // File is new or modified, needs loading
          filesToLoad.add(file);
          _lastModified[date] = currentModified;
        }
      } catch (e) {
        Log.e(
            '❌ DailyRepository: Error checking file modification time ${file.path}',
            error: e);
        filesToLoad.add(file);
      }
    }

    // Remove cached files that no longer exist
    final existingDates = fileDates.keys.toSet();
    _cache.removeWhere((date, _) => !existingDates.contains(date));
    _lastModified.removeWhere((date, _) => !existingDates.contains(date));

    // Parallel load files that need updating
    final loadedFiles = await _loadFilesParallel(filesToLoad);

    // Update cache with newly loaded files
    for (final dailyFile in loadedFiles) {
      _cache[dailyFile.date] = dailyFile;
    }

    // Combine cached and newly loaded files
    final allFiles = [...cachedFiles, ...loadedFiles];

    // Sort by date descending
    allFiles.sort((a, b) => b.date.compareTo(a.date));

    Log.i(
        '📅 DailyRepository: Loaded ${allFiles.length} daily files (${cachedFiles.length} from cache, ${loadedFiles.length} newly loaded)');
    return allFiles;
  }

  /// Load multiple files in parallel for better performance (batched)
  Future<List<DailyFile>> _loadFilesParallel(List<File> files) async {
    if (files.isEmpty) return [];

    Log.d('📅 DailyRepository: Loading ${files.length} files in parallel...');
    final stopwatch = Stopwatch()..start();

    try {
      final loadedFiles = <DailyFile>[];
      const batchSize = 20;

      for (var i = 0; i < files.length; i += batchSize) {
        final batch = files.skip(i).take(batchSize);
        final futures = batch.map((file) => _loadSingleFile(file));
        final results = await Future.wait(futures);
        loadedFiles.addAll(results.whereType<DailyFile>());
      }

      stopwatch.stop();
      Log.d(
          '📅 DailyRepository: Parallel loading completed in ${stopwatch.elapsedMilliseconds}ms');

      return loadedFiles;
    } catch (e) {
      Log.e('❌ DailyRepository: Error in parallel file loading', error: e);

      // Fallback to sequential loading if parallel fails
      Log.w('📅 DailyRepository: Falling back to sequential loading');
      return await _loadFilesSequential(files);
    }
  }

  /// Load files sequentially as fallback
  Future<List<DailyFile>> _loadFilesSequential(List<File> files) async {
    final loadedFiles = <DailyFile>[];

    for (final file in files) {
      try {
        final dailyFile = await _loadSingleFile(file);
        if (dailyFile != null) {
          loadedFiles.add(dailyFile);
        }
      } catch (e) {
        Log.e('❌ DailyRepository: Error loading daily file ${file.path}',
            error: e);
      }
    }

    return loadedFiles;
  }

  /// Load a single daily file
  Future<DailyFile?> _loadSingleFile(File file) async {
    try {
      final fileName = path.basename(file.path);
      final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
      if (dateMatch == null) return null;

      final date = dateMatch.group(1)!;
      final content = await _storageService.readFile(file);

      return DailyFile(
        path: file.path,
        date: date,
        content: content,
      );
    } catch (e) {
      Log.e('❌ DailyRepository: Error loading daily file ${file.path}',
          error: e);
      return null;
    }
  }

  /// Incremental update - only load files modified since last load
  Future<List<DailyFile>> loadIncremental() async {
    Log.d('📅 DailyRepository: Loading incremental changes...');

    final dir = _storageService.dailiesDirectory;
    if (dir == null) {
      Log.e('❌ DailyRepository: Dailies directory not initialized');
      return _cache.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    }

    final files = _storageService.listFiles(dir);
    final modifiedFiles = <File>[];
    final modifiedDates = <String>{};

    // Check for modified files
    for (final file in files) {
      try {
        final fileName = path.basename(file.path);
        final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
        if (dateMatch == null) continue;

        final date = dateMatch.group(1)!;
        final currentModified = file.lastModifiedSync();

        if (_lastModified[date] == null ||
            _lastModified[date]!.isBefore(currentModified)) {
          modifiedFiles.add(file);
          modifiedDates.add(date);
          _lastModified[date] = currentModified;
        }
      } catch (e) {
        Log.e(
            '❌ DailyRepository: Error checking file modification time ${file.path}',
            error: e);
      }
    }

    // Remove deleted files from cache
    final existingDates = files
        .map((f) => path.basename(f.path))
        .where((name) => RegExp(r'(\d{8})\.md$').hasMatch(name))
        .map((name) => RegExp(r'(\d{8})\.md$').firstMatch(name)!.group(1)!)
        .toSet();

    _cache.removeWhere((date, _) => !existingDates.contains(date));
    _lastModified.removeWhere((date, _) => !existingDates.contains(date));

    // Load modified files in parallel
    final loadedFiles = await _loadFilesParallel(modifiedFiles);

    // Update cache
    for (final dailyFile in loadedFiles) {
      _cache[dailyFile.date] = dailyFile;
    }

    final allFiles = _cache.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    Log.i(
        '📅 DailyRepository: Incremental load completed - ${loadedFiles.length} files updated, ${allFiles.length} total');
    return allFiles;
  }

  /// Get daily file by date from cache
  DailyFile? getByDate(String date) {
    return _cache[date];
  }

  /// Check if a daily file exists on disk for the given date and load it
  Future<DailyFile?> loadByDate(String date) async {
    // First check cache
    final cached = _cache[date];
    if (cached != null) {
      return cached;
    }

    // Check if file exists on disk
    final dir = _storageService.dailiesDirectory;
    if (dir == null) {
      Log.e('❌ DailyRepository: Dailies directory not initialized');
      return null;
    }

    final filePath = path.join(dir.path, '$date.md');
    final file = File(filePath);

    if (!await file.exists()) {
      Log.d('📅 DailyRepository: No file exists for date $date');
      return null;
    }

    // Load the file from disk
    Log.i('📅 DailyRepository: Loading daily file for $date from disk');
    final dailyFile = await _loadSingleFile(file);
    if (dailyFile != null) {
      _cache[date] = dailyFile;
      _lastModified[date] = file.lastModifiedSync();
    }
    return dailyFile;
  }

  /// Save daily file
  Future<void> save(DailyFile dailyFile) async {
    try {
      final file = File(dailyFile.path);
      await _storageService.writeFile(file, dailyFile.content);
      _cache[dailyFile.date] = dailyFile;
      Log.d('📅 DailyRepository: Saved daily file for ${dailyFile.date}');
    } catch (e) {
      Log.e('❌ DailyRepository: Error saving daily file', error: e);
      rethrow;
    }
  }

  /// Create new daily file
  Future<DailyFile> create(String date, String content) async {
    final dir = _storageService.dailiesDirectory;
    if (dir == null) {
      throw Exception('Dailies directory not initialized');
    }

    final filePath = path.join(dir.path, '$date.md');

    final dailyFile = DailyFile(
      path: filePath,
      date: date,
      content: content,
    );

    await save(dailyFile);
    return dailyFile;
  }

  /// Get cached files count
  int get cacheSize => _cache.length;

  /// Clear cache manually
  void clearCache() {
    _cache.clear();
    _lastModified.clear();
    Log.d('📅 DailyRepository: Cache cleared');
  }
}
