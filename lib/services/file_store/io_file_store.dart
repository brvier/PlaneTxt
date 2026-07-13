import 'dart:io';

import 'package:planova/services/file_store/file_store.dart';
import 'package:planova/utils/logger.dart';

/// [FileStore] over a plain filesystem directory (dart:io).
///
/// Used for the default app-private storage root on all platforms, and for
/// user-selected raw paths on desktop.
class IoFileStore extends FileStore {
  final Directory root;

  IoFileStore(this.root);

  @override
  String get rootDescription => root.path;

  @override
  bool get supportsNativeWatch => true;

  String _abs(String relPath) => '${root.path}/${normalizeRelPath(relPath)}';

  @override
  Future<void> ensureDirectory(String relDir) async {
    await Directory(_abs(relDir)).create(recursive: true);
  }

  @override
  Future<List<StoreEntry>> list(
    String relDir, {
    String extension = '.md',
    bool recursive = false,
  }) async {
    final dir = Directory(_abs(relDir));
    if (!await dir.exists()) return const [];

    final prefix = '${root.path}/';
    final entries = <StoreEntry>[];
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is! File || !entity.path.endsWith(extension)) continue;
      DateTime? mtime;
      try {
        mtime = await entity.lastModified();
      } catch (_) {
        // Deleted between list and stat - skip.
        continue;
      }
      final rel = entity.path.startsWith(prefix)
          ? entity.path.substring(prefix.length)
          : entity.path;
      entries.add(StoreEntry(rel.replaceAll('\\', '/'), mtime));
    }
    return entries;
  }

  @override
  Future<String?> read(String relPath) async {
    final file = File(_abs(relPath));
    try {
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      Log.e('❌ IoFileStore: Error reading $relPath', error: e);
      return null;
    }
  }

  /// Atomic write: temp file in the same directory, flush, rename over the
  /// target. A crash mid-write can never leave a truncated file behind - the
  /// user's plaintext files ARE the data.
  @override
  Future<void> write(String relPath, String content) async {
    final target = File(_abs(relPath));
    await target.parent.create(recursive: true);
    final tempFile = File('${target.path}.tmp');
    try {
      await tempFile.writeAsString(content, flush: true);
      await tempFile.rename(target.path);
    } catch (e) {
      Log.e('❌ IoFileStore: Error writing $relPath', error: e);
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> delete(String relPath) async {
    final file = File(_abs(relPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> exists(String relPath) => File(_abs(relPath)).exists();

  @override
  Future<DateTime?> modified(String relPath) async {
    try {
      return await File(_abs(relPath)).lastModified();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> rename(String fromRelPath, String toRelPath) async {
    final target = File(_abs(toRelPath));
    await target.parent.create(recursive: true);
    await File(_abs(fromRelPath)).rename(target.path);
  }

  @override
  Stream<void>? watchDirectory(String relDir) {
    try {
      return Directory(_abs(relDir)).watch();
    } catch (_) {
      return null;
    }
  }
}
