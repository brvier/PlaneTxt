import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:planetxt/services/storage_service.dart';
import 'package:planetxt/utils/logger.dart';

/// Base class for file-backed repositories with caching, parallel loading,
/// incremental updates, and disk-persisted cache.
///
/// Files are addressed by store-relative paths (see [StorageService]);
/// listing/reading goes through the active [FileStore], so the same code
/// serves the private directory, a desktop custom path, or an Android SAF
/// tree.
///
/// Subclasses provide:
///  - [scanDir]: the store directory to scan (e.g. `dailies`)
///  - [cacheFileName]: name of the on-disk cache file
///  - [tag]: log prefix (e.g. '📅 DailyRepository')
///  - [matchEntry] / [loadSingleEntry]: how to recognise and parse files
///  - [fileKey]: unique cache key for an item (date, relativePath, …)
///  - [serializeItem] / [deserializeItem]: JSON round-trip for disk cache
abstract class BaseRepository<T> {
  final StorageService storageService;

  final Map<String, T> cache = {};
  final Map<String, DateTime> lastModified = {};

  BaseRepository(this.storageService);

  // --- abstract hooks -------------------------------------------------------

  /// The store-relative directory this repository scans.
  String get scanDir;

  /// File name used for the on-disk JSON cache (e.g. `._daily_cache.json`).
  String get cacheFileName;

  /// Short tag for log messages (e.g. `📅 DailyRepository`).
  String get tag;

  /// Whether listing should recurse into subdirectories.
  bool get recursive => false;

  /// Return a unique cache key for the given [entry], or `null` to skip it.
  String? matchEntry(StoreEntry entry);

  /// Build a model from a listed entry and its file content. Return `null`
  /// to skip the file.
  T? itemFromContent(StoreEntry entry, String content);

  /// Load one file from the store and return a model, or `null` when the
  /// file is missing. Batch loading goes through [FileStore.readAll]
  /// instead - use this only for single-file paths (e.g. loadByDate).
  Future<T?> loadSingleEntry(StoreEntry entry) async {
    final content = await storageService.store?.read(entry.relPath);
    if (content == null) return null;
    return itemFromContent(entry, content);
  }

  /// Return the cache key for an already-loaded item.
  String fileKey(T item);

  /// Serialise [item] for disk cache.
  Map<String, dynamic> serializeItem(T item, DateTime? mtime);

  /// Deserialise [item] from disk cache.  Returns `(item, mtime)`.
  (T, DateTime?) deserializeItem(String key, Map<String, dynamic> data);

  /// Sorting comparator (newest first, typically).
  int compare(T a, T b);

  // --- public API -----------------------------------------------------------

  /// [onProgress] is called after each loaded batch with
  /// `(filesLoaded, filesToLoad)` - lets the UI show a "building cache"
  /// indicator on the first full scan, which reads every file (slow on
  /// large folders and SAF trees).
  Future<List<T>> loadAll({
    bool forceReload = false,
    void Function(int done, int total)? onProgress,
  }) async {
    Log.d('$tag: Loading all files (forceReload: $forceReload)...');

    final store = storageService.store;
    if (store == null) {
      Log.e('❌ $tag: Storage not initialized');
      return [];
    }

    if (cache.isEmpty && !forceReload) {
      await _restoreCache();
    }

    final entries = await store.list(scanDir, recursive: recursive);

    if (forceReload) {
      cache.clear();
      lastModified.clear();
    }

    final entriesToLoad = <StoreEntry>[];
    final cachedItems = <T>[];
    final seenKeys = <String>{};

    for (final entry in entries) {
      final key = matchEntry(entry);
      if (key == null) continue;
      seenKeys.add(key);

      final currentMod = entry.modified;
      final cached = cache[key];

      if (cached != null &&
          currentMod != null &&
          lastModified[key] != null &&
          !lastModified[key]!.isBefore(currentMod) &&
          !forceReload) {
        cachedItems.add(cached);
      } else {
        entriesToLoad.add(entry);
        if (currentMod != null) lastModified[key] = currentMod;
      }
    }

    final removedCount =
        cache.length - cache.keys.where(seenKeys.contains).length;
    cache.removeWhere((k, _) => !seenKeys.contains(k));
    lastModified.removeWhere((k, _) => !seenKeys.contains(k));

    final loadedItems =
        await _loadEntriesParallel(entriesToLoad, onProgress: onProgress);

    for (final item in loadedItems) {
      cache[fileKey(item)] = item;
    }

    final allItems = [...cachedItems, ...loadedItems]..sort(compare);

    Log.i(
        '$tag: Loaded ${allItems.length} files (${cachedItems.length} from cache, ${loadedItems.length} newly loaded)');

    // Only rewrite the disk cache when something actually changed.
    if (loadedItems.isNotEmpty || removedCount > 0 || forceReload) {
      await _persistCache();
    }
    return allItems;
  }

  Future<List<T>> loadIncremental() async {
    Log.d('$tag: Loading incremental changes...');

    final store = storageService.store;
    if (store == null) {
      Log.e('❌ $tag: Storage not initialized');
      return cache.values.toList()..sort(compare);
    }

    final entries = await store.list(scanDir, recursive: recursive);
    final modifiedEntries = <StoreEntry>[];
    final seenKeys = <String>{};

    for (final entry in entries) {
      final key = matchEntry(entry);
      if (key == null) continue;
      seenKeys.add(key);

      final currentMod = entry.modified;

      if (currentMod == null ||
          lastModified[key] == null ||
          lastModified[key]!.isBefore(currentMod)) {
        modifiedEntries.add(entry);
        if (currentMod != null) lastModified[key] = currentMod;
      }
    }

    cache.removeWhere((k, _) => !seenKeys.contains(k));
    lastModified.removeWhere((k, _) => !seenKeys.contains(k));

    final loadedItems = await _loadEntriesParallel(modifiedEntries);

    for (final item in loadedItems) {
      cache[fileKey(item)] = item;
    }

    final allItems = cache.values.toList()..sort(compare);

    Log.i(
        '$tag: Incremental load completed - ${loadedItems.length} files updated, ${allItems.length} total');

    if (loadedItems.isNotEmpty) {
      await _persistCache();
    }

    return allItems;
  }

  /// Quickly populate [cache] from the on-disk JSON cache and return the
  /// items sorted by [compare]. Does NOT scan the filesystem or revalidate
  /// mtimes - intended as a "fast first paint" stage before [loadAll].
  Future<List<T>> restoreFromDiskCache() async {
    if (cache.isEmpty) {
      await _restoreCache();
    }
    if (cache.isEmpty) return const [];
    return cache.values.toList()..sort(compare);
  }

  /// Persist the in-memory cache to disk now. Call after user edits: the
  /// startup fast path ([restoreFromDiskCache]) paints from this file, so a
  /// process kill before the next full scan must not lose the latest saves.
  Future<void> persistCache() => _persistCache();

  int get cacheSize => cache.length;

  void clearCache() {
    cache.clear();
    lastModified.clear();
    Log.d('$tag: Cache cleared');
  }

  // --- parallel loading -----------------------------------------------------

  Future<List<T>> _loadEntriesParallel(
    List<StoreEntry> entries, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (entries.isEmpty) return [];

    Log.d('$tag: Loading ${entries.length} files in parallel...');
    final sw = Stopwatch()..start();

    try {
      final store = storageService.store!;
      final loaded = <T>[];
      const batchSize = 20;
      var done = 0;

      for (var i = 0; i < entries.length; i += batchSize) {
        final batch = entries.skip(i).take(batchSize).toList();
        // One bulk read per batch: on SAF each directory is resolved once
        // for the whole batch instead of once per file.
        final contents =
            await store.readAll(batch.map((e) => e.relPath).toList());
        for (final entry in batch) {
          final content = contents[entry.relPath];
          if (content == null) continue; // vanished between list and read
          final item = itemFromContent(entry, content);
          if (item != null) loaded.add(item);
        }
        done += batch.length;
        onProgress?.call(done, entries.length);
      }

      sw.stop();
      Log.d('$tag: Parallel loading completed in ${sw.elapsedMilliseconds}ms');
      return loaded;
    } catch (e) {
      Log.e('❌ $tag: Error in parallel loading, falling back to sequential',
          error: e);
      return _loadEntriesSequential(entries);
    }
  }

  Future<List<T>> _loadEntriesSequential(List<StoreEntry> entries) async {
    final loaded = <T>[];
    for (final entry in entries) {
      try {
        final item = await loadSingleEntry(entry);
        if (item != null) loaded.add(item);
      } catch (e) {
        Log.e('❌ $tag: Error loading file ${entry.relPath}', error: e);
      }
    }
    return loaded;
  }

  // --- disk cache -----------------------------------------------------------
  //
  // Cache files live in the app-private directory (storageService
  // .cacheFilePath): always writable with plain dart:io - even when the
  // storage root is a SAF tree - and never synced to the user's folder.

  static const _cacheVersion = 2; // v2: store-relative paths

  Future<void> _persistCache() async {
    try {
      if (!storageService.isInitialized) return;
      final cacheFile = File(storageService.cacheFilePath(cacheFileName));

      final data = <String, dynamic>{
        'version': _cacheVersion,
        'files': <String, dynamic>{},
      };

      for (final entry in cache.entries) {
        (data['files'] as Map<String, dynamic>)[entry.key] =
            serializeItem(entry.value, lastModified[entry.key]);
      }

      // The cache holds the full content of every file - encoding it on the
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
      if (!storageService.isInitialized) return;
      final cacheFilePath = storageService.cacheFilePath(cacheFileName);
      if (!await File(cacheFilePath).exists()) return;

      // Read + decode off the UI isolate; the result transfers back via
      // Isolate.exit without a copy.
      final data = await Isolate.run(() async {
        final content = await File(cacheFilePath).readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      });

      if (data['version'] != _cacheVersion) return;

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
