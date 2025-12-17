import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/models/daily_file.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';

class DailyRepository {
  final StorageService _storageService;
  final Map<String, DailyFile> _cache = {};

  DailyRepository(this._storageService);

  /// Load all daily files
  Future<List<DailyFile>> loadAll() async {
    Log.d('📅 DailyRepository: Loading all daily files...');
    _cache.clear();

    final dir = _storageService.dailiesDirectory;
    if (dir == null) {
      Log.e('❌ DailyRepository: Dailies directory not initialized');
      return [];
    }

    final files = _storageService.listFiles(dir);
    final dailyFiles = <DailyFile>[];

    for (final file in files) {
      try {
        final fileName = path.basename(file.path);
        final dateMatch = RegExp(r'(\d{8})\.md$').firstMatch(fileName);
        if (dateMatch != null) {
          final date = dateMatch.group(1)!;
          final content = await _storageService.readFile(file);
          final dailyFile = DailyFile(
            path: file.path,
            date: date,
            content: content,
          );
          _cache[date] = dailyFile;
          dailyFiles.add(dailyFile);
        }
      } catch (e) {
        Log.e('❌ DailyRepository: Error loading daily file ${file.path}', e);
      }
    }

    // Sort by date descending
    dailyFiles.sort((a, b) => b.date.compareTo(a.date));
    Log.i('📅 DailyRepository: Loaded ${dailyFiles.length} daily files');
    return dailyFiles;
  }

  /// Get daily file by date
  DailyFile? getByDate(String date) {
    return _cache[date];
  }

  /// Save daily file
  Future<void> save(DailyFile dailyFile) async {
    try {
      final file = File(dailyFile.path);
      await _storageService.writeFile(file, dailyFile.content);
      _cache[dailyFile.date] = dailyFile;
      Log.d('📅 DailyRepository: Saved daily file for ${dailyFile.date}');
    } catch (e) {
      Log.e('❌ DailyRepository: Error saving daily file', e);
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
}
