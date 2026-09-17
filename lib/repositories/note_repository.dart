import 'package:path/path.dart' as path;
import 'package:planetxt/models/note_file.dart';
import 'package:planetxt/repositories/base_repository.dart';
import 'package:planetxt/services/storage_service.dart';
import 'package:planetxt/utils/logger.dart';

class NoteRepository extends BaseRepository<NoteFile> {
  NoteRepository(super.storageService);

  static final _notesPrefix = '${StorageService.notesDirName}/';

  @override
  String get scanDir => StorageService.notesDirName;

  @override
  String get cacheFileName => '._note_cache.json';

  @override
  String get tag => '📝 NoteRepository';

  @override
  bool get recursive => true;

  /// Store path (`notes/a/b.md`) → path relative to the notes dir (`a/b.md`).
  String _relativeToNotes(String relPath) =>
      relPath.startsWith(_notesPrefix)
          ? relPath.substring(_notesPrefix.length)
          : relPath;

  @override
  String? matchEntry(StoreEntry entry) => _relativeToNotes(entry.relPath);

  @override
  NoteFile? itemFromContent(StoreEntry entry, String content) {
    return NoteFile(
      path: entry.relPath,
      relativePath: _relativeToNotes(entry.relPath),
      content: content,
      lastModified: entry.modified ?? DateTime.now(),
    );
  }

  @override
  String fileKey(NoteFile item) => item.relativePath;

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
      await storageService.store!.write(noteFile.path, noteFile.content);
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
    if (!storageService.isInitialized) {
      throw Exception('Storage not initialized');
    }

    final sanitizedRelativePath = _sanitizeRelativePath(relativePath);

    final noteFile = NoteFile(
      path: StorageService.notePath(sanitizedRelativePath),
      relativePath: sanitizedRelativePath,
      content: content,
      lastModified: DateTime.now(),
    );

    await save(noteFile);
    return noteFile;
  }

  /// Rename/move a note within the notes directory.
  Future<NoteFile> rename(NoteFile noteFile, String newRelativePath) async {
    final sanitized = _sanitizeRelativePath(newRelativePath);
    final newStorePath = StorageService.notePath(sanitized);

    final store = storageService.store!;
    if (await store.exists(newStorePath)) {
      throw ArgumentError('A note named $sanitized already exists');
    }

    await store.rename(noteFile.path, newStorePath);
    cache.remove(noteFile.relativePath);
    lastModified.remove(noteFile.relativePath);

    final renamed = noteFile.copyWith(
      path: newStorePath,
      relativePath: sanitized,
      lastModified: DateTime.now(),
    );
    cache[renamed.relativePath] = renamed;
    Log.d('📝 NoteRepository: Renamed ${noteFile.relativePath} → $sanitized');
    return renamed;
  }

  /// Delete note file.
  Future<void> delete(NoteFile noteFile) async {
    try {
      await storageService.store!.delete(noteFile.path);
      cache.remove(noteFile.relativePath);
      Log.d('📝 NoteRepository: Deleted note file ${noteFile.relativePath}');
    } catch (e) {
      Log.e('❌ NoteRepository: Error deleting note file', error: e);
      rethrow;
    }
  }
}
