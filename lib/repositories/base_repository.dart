import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';

/// Base class for file-backed repositories with caching, parallel loading,
/// incremental updates, and disk-persisted cache.
///
/// Subclasses provide:
///  - [directory]: the directory to scan
///  - [cacheFileName]: name of the on-disk cache file
///  - [tag]: log prefix (e.g. '📅 DailyRepository')
///  - [matchFile] / [loadSingleFile]: how to recognise and parse files
///  - [fileKey]: unique cache key for an item (date, relativePath, …)
///  - [serializeItem] / [deserializeItem]: JSON round-trip for disk cache
abstract class BaseRepository<T> {
  final StorageService storageService;

  final Map<String, T> cache = {};
  final Map<String, DateTime> lastModified = {};

  BaseRepository(this.storageService);

  // --- abstract hooks -------------------------------------------------------

  /// The directory this repository scans.
  Directory? get directory;

  /// File name used for the on-disk JSON cache (e.g. `._daily_cache.json`).
  String get cacheFileName;

  /// Short tag for log messages (e.g. `📅 DailyRepository`).
  String get tag;

  /// Whether [listFiles] should recurse into subdirectories.
  bool get recursive => false;

  /// Return a unique cache key for the given [file], or `null` to skip it.
  String? matchFile(File file);

  /// Load one file from disk and return a model, or `null` on failure.
  Future<T?> loadSingleFile(File file);

  /// Return the cache key for an already-loaded item.
  String fileKey(T item);

  /// Serialise [item] for disk cache.
  Map<String, dynamic> serializeItem(T item, DateTime? mtime);

  /// Deserialise [item] from disk cache.  Returns `(item, mtime)`.
  (T, DateTime?) deserializeItem(String key, Map<String, dynamic> data);

  /// Return a copy of [item] with an updated path (in case the directory moved).
  T copyWithPath(T item, String newPath);

  /// Sorting comparator (newest first, typically).
  int compare(T a, T b);

  // --- public API -----------------------------------------------------------

  Future<List<T>> loadAll({bool forceReload = false}) async {
    Log.d('$tag: Loading all files (forceReload: $forceReload)...');

    final dir = directory;
    if (dir == null) {
      Log.e('❌ $tag: Directory not initialized');
      return [];
    }

    if (cache.isEmpty && !forceReload) {
      await _restoreCache();
    }

    final files = await storageService.listFilesAsync(dir, recursive: recursive);

    if (forceReload) {
      cache.clear();
      lastModified.clear();
    }

    final filesToLoad = <File>[];
    final cachedFiles = <T>[];
    final seenKeys = <String>{};

    for (final file in files) {
      try {
        final key = matchFile(file);
        if (key == null) continue;
        seenKeys.add(key);

        final currentMod = await file.lastModified();
        final cached = cache[key];

        if (cached != null &&
            lastModified[key] != null &&
            !lastModified[key]!.isBefore(currentMod) &&
            !forceReload) {
          cachedFiles.add(copyWithPath(cached, file.path));
        } else {
          filesToLoad.add(file);
          lastModified[key] = currentMod;
        }
      } catch (e) {
        Log.e('❌ $tag: Error checking file ${file.path}', error: e);
        filesToLoad.add(file);
      }
    }

    final removedCount = cache.length -
        cache.keys.where(seenKeys.contains).length;
    cache.removeWhere((k, _) => !seenKeys.contains(k));
    lastModified.removeWhere((k, _) => !seenKeys.contains(k));

    final loadedFiles = await _loadFilesParallel(filesToLoad);

    for (final item in loadedFiles) {
      cache[fileKey(item)] = item;
    }

    final allFiles = [...cachedFiles, ...loadedFiles]..sort(compare);

    Log.i(
        '$tag: Loaded ${allFiles.length} files (${cachedFiles.length} from cache, ${loadedFiles.length} newly loaded)');

    // Only rewrite the disk cache when something actually changed.
    if (loadedFiles.isNotEmpty || removedCount > 0 || forceReload) {
      await _persistCache();
    }
    return allFiles;
  }

  Future<List<T>> loadIncremental() async {
    Log.d('$tag: Loading incremental changes...');

    final dir = directory;
    if (dir == null) {
      Log.e('❌ $tag: Directory not initialized');
      return cache.values.toList()..sort(compare);
    }

    final files = await storageService.listFilesAsync(dir, recursive: recursive);
    final modifiedFiles = <File>[];
    final seenKeys = <String>{};

    for (final file in files) {
      try {
        final key = matchFile(file);
        if (key == null) continue;
        seenKeys.add(key);

        final currentMod = await file.lastModified();

        if (lastModified[key] == null ||
            lastModified[key]!.isBefore(currentMod)) {
          modifiedFiles.add(file);
          lastModified[key] = currentMod;
        }
      } catch (e) {
        Log.e('❌ $tag: Error checking file ${file.path}', error: e);
      }
    }

    cache.removeWhere((k, _) => !seenKeys.contains(k));
    lastModified.removeWhere((k, _) => !seenKeys.contains(k));

    final loadedFiles = await _loadFilesParallel(modifiedFiles);

    for (final item in loadedFiles) {
      cache[fileKey(item)] = item;
    }

    final allFiles = cache.values.toList()..sort(compare);

    Log.i(
        '$tag: Incremental load completed - ${loadedFiles.length} files updated, ${allFiles.length} total');

    if (loadedFiles.isNotEmpty) {
      await _persistCache();
    }

    return allFiles;
  }

  /// Quickly populate [cache] from the on-disk JSON cache and return the
  /// items sorted by [compare]. Does NOT scan the filesystem or revalidate
  /// mtimes — intended as a "fast first paint" stage before [loadAll].
  Future<List<T>> restoreFromDiskCache() async {
    if (cache.isEmpty) {
      await _restoreCache();
    }
    if (cache.isEmpty) return const [];
    return cache.values.toList()..sort(compare);
  }

  int get cacheSize => cache.length;

  void clearCache() {
    cache.clear();
    lastModified.clear();
    Log.d('$tag: Cache cleared');
  }

  // --- parallel loading -----------------------------------------------------

  Future<List<T>> _loadFilesParallel(List<File> files) async {
    if (files.isEmpty) return [];

    Log.d('$tag: Loading ${files.length} files in parallel...');
    final sw = Stopwatch()..start();

    try {
      final loaded = <T>[];
      const batchSize = 20;

      for (var i = 0; i < files.length; i += batchSize) {
        final batch = files.skip(i).take(batchSize);
        final futures = batch.map((f) => loadSingleFile(f));
        final results = await Future.wait(futures);
        for (final r in results) {
          if (r != null) loaded.add(r);
        }
      }

      sw.stop();
      Log.d('$tag: Parallel loading completed in ${sw.elapsedMilliseconds}ms');
      return loaded;
    } catch (e) {
      Log.e('❌ $tag: Error in parallel loading, falling back to sequential',
          error: e);
      return _loadFilesSequential(files);
    }
  }

  Future<List<T>> _loadFilesSequential(List<File> files) async {
    final loaded = <T>[];
    for (final file in files) {
      try {
        final item = await loadSingleFile(file);
        if (item != null) loaded.add(item);
      } catch (e) {
        Log.e('❌ $tag: Error loading file ${file.path}', error: e);
      }
    }
    return loaded;
  }

  // --- disk cache -----------------------------------------------------------

  Future<void> _persistCache() async {
    try {
      final dir = storageService.orgDirectory;
      if (dir == null) return;

      final cacheFile = File('${dir.path}/$cacheFileName');
      final data = <String, dynamic>{
        'version': 1,
        'files': <String, dynamic>{},
      };

      for (final entry in cache.entries) {
        (data['files'] as Map<String, dynamic>)[entry.key] =
            serializeItem(entry.value, lastModified[entry.key]);
      }

      // The cache holds the full content of every file — encoding it on the
      // UI isolate janks frames once the history grows.
      final encoded = await Isolate.run(() => jsonEncode(data));
      await cacheFile.writeAsString(encoded);
      Log.d('$tag: Persisted ${cache.length} files to disk cache');
    } catch (e) {
      Log.e('❌ $tag: Error persisting cache', error: e);
    }
  }

  Future<void> _restoreCache() async {
    try {
      final dir = storageService.orgDirectory;
      if (dir == null) return;

      final cacheFilePath = '${dir.path}/$cacheFileName';
      if (!await File(cacheFilePath).exists()) return;

      // Read + decode off the UI isolate; the result transfers back via
      // Isolate.exit without a copy.
      final data = await Isolate.run(() async {
        final content = await File(cacheFilePath).readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      });

      if (data['version'] != 1) return;

      final files = data['files'] as Map<String, dynamic>;
      for (final entry in files.entries) {
        final fileData = entry.value as Map<String, dynamic>;
        final (item, mtime) = deserializeItem(entry.key, fileData);
        cache[entry.key] = item;
        if (mtime != null) {
          lastModified[entry.key] = mtime;
        }
      }

      Log.i('$tag: Restored ${cache.length} files from disk cache');
    } catch (e) {
      Log.e('❌ $tag: Error restoring cache, will do full load', error: e);
      cache.clear();
      lastModified.clear();
    }
  }
}
