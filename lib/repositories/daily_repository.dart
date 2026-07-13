import 'package:planova/models/daily_file.dart';
import 'package:planova/repositories/base_repository.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';

class DailyRepository extends BaseRepository<DailyFile> {
  static final _datePattern = RegExp(r'(\d{8})\.md$');

  DailyRepository(super.storageService);

  @override
  String get scanDir => StorageService.dailiesDirName;

  @override
  String get cacheFileName => '._daily_cache.json';

  @override
  String get tag => '📅 DailyRepository';

  @override
  String? matchEntry(StoreEntry entry) {
    final fileName = entry.relPath.split('/').last;
    final match = _datePattern.firstMatch(fileName);
    return match?.group(1);
  }

  @override
  DailyFile? itemFromContent(StoreEntry entry, String content) {
    final fileName = entry.relPath.split('/').last;
    final dateMatch = _datePattern.firstMatch(fileName);
    if (dateMatch == null) return null;

    return DailyFile(
        path: entry.relPath, date: dateMatch.group(1)!, content: content);
  }

  @override
  String fileKey(DailyFile item) => item.date;

  @override
  int compare(DailyFile a, DailyFile b) => b.date.compareTo(a.date);

  @override
  Map<String, dynamic> serializeItem(DailyFile item, DateTime? mtime) => {
        'content': item.content,
        'path': item.path,
        'mtime': mtime?.millisecondsSinceEpoch,
      };

  @override
  (DailyFile, DateTime?) deserializeItem(
      String key, Map<String, dynamic> data) {
    final item = DailyFile(
      path: data['path'] as String,
      date: key,
      content: data['content'] as String,
    );
    final mtime = data['mtime'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['mtime'] as int)
        : null;
    return (item, mtime);
  }

  // --- domain-specific methods ----------------------------------------------

  /// Get daily file by date from cache.
  DailyFile? getByDate(String date) => cache[date];

  /// Load the daily file for [date], revalidating the cache against the
  /// file's mtime. The plaintext files can be edited by external tools at
  /// any time - returning a stale cache entry here would make the next save
  /// silently overwrite those edits.
  Future<DailyFile?> loadByDate(String date) async {
    final store = storageService.store;
    if (store == null) {
      Log.e('❌ DailyRepository: Storage not initialized');
      return cache[date];
    }

    final relPath = StorageService.dailyPath(date);
    final currentMod = await store.modified(relPath);

    if (currentMod == null && !await store.exists(relPath)) {
      Log.d('📅 DailyRepository: No file exists for date $date');
      cache.remove(date);
      lastModified.remove(date);
      return null;
    }

    final cached = cache[date];
    final cachedMod = lastModified[date];
    if (cached != null &&
        cachedMod != null &&
        currentMod != null &&
        !cachedMod.isBefore(currentMod)) {
      return cached;
    }

    Log.i('📅 DailyRepository: Loading daily file for $date from disk');
    final dailyFile = await loadSingleEntry(StoreEntry(relPath, currentMod));
    if (dailyFile != null) {
      cache[date] = dailyFile;
      if (currentMod != null) lastModified[date] = currentMod;
    }
    return dailyFile;
  }

  /// Save daily file.
  Future<void> save(DailyFile dailyFile) async {
    try {
      final store = storageService.store!;
      await store.write(dailyFile.path, dailyFile.content);
      cache[dailyFile.date] = dailyFile;
      // Record the new mtime so loadByDate doesn't re-read our own write.
      try {
        final mtime = await store.modified(dailyFile.path);
        if (mtime != null) lastModified[dailyFile.date] = mtime;
      } catch (_) {}
      Log.d('📅 DailyRepository: Saved daily file for ${dailyFile.date}');
    } catch (e) {
      Log.e('❌ DailyRepository: Error saving daily file', error: e);
      rethrow;
    }
  }

  /// Create new daily file.
  Future<DailyFile> create(String date, String content) async {
    if (!storageService.isInitialized) {
      throw Exception('Storage not initialized');
    }

    final dailyFile = DailyFile(
      path: StorageService.dailyPath(date),
      date: date,
      content: content,
    );
    await save(dailyFile);
    return dailyFile;
  }
}
