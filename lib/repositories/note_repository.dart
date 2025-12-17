import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:planova/models/note_file.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/utils/logger.dart';

class NoteRepository {
  final StorageService _storageService;
  List<NoteFile> _cache = [];

  NoteRepository(this._storageService);

  /// Load all note files
  Future<List<NoteFile>> loadAll() async {
    Log.d('📝 NoteRepository: Loading all note files...');
    _cache.clear();

    final dir = _storageService.notesDirectory;
    if (dir == null) {
      Log.e('❌ NoteRepository: Notes directory not initialized');
      return [];
    }

    final files = _storageService.listFiles(dir, recursive: true);
    final noteFiles = <NoteFile>[];

    for (final file in files) {
      try {
        final content = await _storageService.readFile(file);
        final relativePath =
            path.relative(file.path, from: dir.path).replaceAll('\\', '/');
        final lastModified = file.lastModifiedSync();

        final noteFile = NoteFile(
          path: file.path,
          relativePath: relativePath,
          content: content,
          lastModified: lastModified,
        );
        noteFiles.add(noteFile);
      } catch (e) {
        Log.e('❌ NoteRepository: Error loading note file ${file.path}', e);
      }
    }

    // Sort by last modified descending
    noteFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    _cache = noteFiles;
    Log.i('📝 NoteRepository: Loaded ${noteFiles.length} note files');
    return noteFiles;
  }

  /// Get cached notes
  List<NoteFile> get cachedNotes => List.unmodifiable(_cache);

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
      Log.e('❌ NoteRepository: Error saving note file', e);
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
      Log.e('❌ NoteRepository: Error deleting note file', e);
      rethrow;
    }
  }
}
