import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/models/daily_file.dart';
import 'package:planova/repositories/base_repository.dart';
import 'package:planova/utils/logger.dart';

class DailyRepository extends BaseRepository<DailyFile> {
  static final _datePattern = RegExp(r'(\d{8})\.md$');

  DailyRepository(super.storageService);

  @override
  Directory? get directory => storageService.dailiesDirectory;

  @override
  String get cacheFileName => '._daily_cache.json';

  @override
  String get tag => '📅 DailyRepository';

  @override
  String? matchFile(File file) {
    final fileName = path.basename(file.path);
    final match = _datePattern.firstMatch(fileName);
    return match?.group(1);
  }

  @override
  Future<DailyFile?> loadSingleFile(File file) async {
    try {
      final fileName = path.basename(file.path);
      final dateMatch = _datePattern.firstMatch(fileName);
      if (dateMatch == null) return null;

      final date = dateMatch.group(1)!;
      final content = await storageService.readFile(file);

      return DailyFile(path: file.path, date: date, content: content);
    } catch (e) {
      Log.e('❌ DailyRepository: Error loading daily file ${file.path}',
          error: e);
      return null;
    }
  }

  @override
  String fileKey(DailyFile item) => item.date;

  @override
  DailyFile copyWithPath(DailyFile item, String newPath) =>
      item.copyWith(path: newPath);

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
  /// any time — returning a stale cache entry here would make the next save
  /// silently overwrite those edits.
  Future<DailyFile?> loadByDate(String date) async {
    final dir = directory;
    if (dir == null) {
      Log.e('❌ DailyRepository: Dailies directory not initialized');
      return cache[date];
    }

    final filePath = path.join(dir.path, '$date.md');
    final file = File(filePath);

    if (!await file.exists()) {
      Log.d('📅 DailyRepository: No file exists for date $date');
      cache.remove(date);
      lastModified.remove(date);
      return null;
    }

    final currentMod = await file.lastModified();
    final cached = cache[date];
    final cachedMod = lastModified[date];
    if (cached != null && cachedMod != null && !cachedMod.isBefore(currentMod)) {
      return cached;
    }

    Log.i('📅 DailyRepository: Loading daily file for $date from disk');
    final dailyFile = await loadSingleFile(file);
    if (dailyFile != null) {
      cache[date] = dailyFile;
      lastModified[date] = currentMod;
    }
    return dailyFile;
  }

  /// Save daily file.
  Future<void> save(DailyFile dailyFile) async {
    try {
      final file = File(dailyFile.path);
      await storageService.writeFile(file, dailyFile.content);
      cache[dailyFile.date] = dailyFile;
      // Record the new mtime so loadByDate doesn't re-read our own write.
      try {
        lastModified[dailyFile.date] = await file.lastModified();
      } catch (_) {}
      Log.d('📅 DailyRepository: Saved daily file for ${dailyFile.date}');
    } catch (e) {
      Log.e('❌ DailyRepository: Error saving daily file', error: e);
      rethrow;
    }
  }

  /// Create new daily file.
  Future<DailyFile> create(String date, String content) async {
    final dir = directory;
    if (dir == null) {
      throw Exception('Dailies directory not initialized');
    }

    final filePath = path.join(dir.path, '$date.md');
    final dailyFile = DailyFile(path: filePath, date: date, content: content);
    await save(dailyFile);
    return dailyFile;
  }
}
