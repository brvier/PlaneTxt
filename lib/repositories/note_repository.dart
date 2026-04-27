import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/models/note_file.dart';
import 'package:planova/repositories/base_repository.dart';
import 'package:planova/utils/logger.dart';

class NoteRepository extends BaseRepository<NoteFile> {
  NoteRepository(super.storageService);

  @override
  Directory? get directory => storageService.notesDirectory;

  @override
  String get cacheFileName => '._note_cache.json';

  @override
  String get tag => '📝 NoteRepository';

  @override
  bool get recursive => true;

  @override
  String? matchFile(File file) {
    final dir = directory;
    if (dir == null) return null;
    return path.relative(file.path, from: dir.path).replaceAll('\\', '/');
  }

  @override
  Future<NoteFile?> loadSingleFile(File file) async {
    try {
      final dir = directory;
      if (dir == null) return null;

      final content = await storageService.readFile(file);
      final relativePath =
          path.relative(file.path, from: dir.path).replaceAll('\\', '/');
      final lastMod = file.lastModifiedSync();

      return NoteFile(
        path: file.path,
        relativePath: relativePath,
        content: content,
        lastModified: lastMod,
      );
    } catch (e) {
      Log.e('❌ NoteRepository: Error loading note file ${file.path}', error: e);
      return null;
    }
  }

  @override
  String fileKey(NoteFile item) => item.relativePath;

  @override
  NoteFile copyWithPath(NoteFile item, String newPath) {
    return item.copyWith(
      path: newPath,
      lastModified: File(newPath).lastModifiedSync(),
    );
  }

  @override
  int compare(NoteFile a, NoteFile b) =>
      b.lastModified.compareTo(a.lastModified);

  @override
  Map<String, dynamic> serializeItem(NoteFile item, DateTime? mtime) => {
        'content': item.content,
        'path': item.path,
        'lastModified': item.lastModified.millisecondsSinceEpoch,
        'mtime': mtime?.millisecondsSinceEpoch,
      };

  @override
  (NoteFile, DateTime?) deserializeItem(
      String key, Map<String, dynamic> data) {
    final item = NoteFile(
      path: data['path'] as String,
      relativePath: key,
      content: data['content'] as String,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        data['lastModified'] as int,
      ),
    );
    final mtime = data['mtime'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['mtime'] as int)
        : null;
    return (item, mtime);
  }

  // --- domain-specific methods ----------------------------------------------

  /// Get cached notes.
  List<NoteFile> get cachedNotes => List.unmodifiable(cache.values);

  /// Save note file.
  Future<void> save(NoteFile noteFile) async {
    try {
      final file = File(noteFile.path);
      await storageService.writeFile(file, noteFile.content);
      cache[noteFile.relativePath] =
          noteFile.copyWith(lastModified: DateTime.now());
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

  /// Create new note file.
  Future<NoteFile> create(String relativePath, String content) async {
    final dir = directory;
    if (dir == null) {
      throw Exception('Notes directory not initialized');
    }

    final sanitizedRelativePath = _sanitizeRelativePath(relativePath);
    final filePath =
        path.normalize(path.join(dir.path, sanitizedRelativePath));

    if (!path.isWithin(dir.path, filePath)) {
      throw ArgumentError('Note path escapes notes directory');
    }

    final file = File(filePath);
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

  /// Delete note file.
  Future<void> delete(NoteFile noteFile) async {
    try {
      final file = File(noteFile.path);
      await storageService.deleteFile(file);
      cache.remove(noteFile.relativePath);
      Log.d('📝 NoteRepository: Deleted note file ${noteFile.relativePath}');
    } catch (e) {
      Log.e('❌ NoteRepository: Error deleting note file', error: e);
      rethrow;
    }
  }
}
