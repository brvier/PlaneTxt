import 'dart:async';

import 'package:flutter/services.dart';
import 'package:planova/services/file_store/file_store.dart';
import 'package:planova/utils/logger.dart';

/// [FileStore] over an Android Storage Access Framework document tree.
///
/// Backed by the `fr.rvier.planova/saf` method channel
/// (SafFileStoreHandler.kt). The tree URI comes from the system folder
/// picker and is persisted across restarts - no storage permission needed.
class SafFileStore extends FileStore {
  static const MethodChannel _channel = MethodChannel('fr.rvier.planova/saf');

  final String treeUri;
  final String displayName;

  SafFileStore(this.treeUri, {String? displayName})
      : displayName = displayName ?? treeUri;

  // --- static channel helpers -------------------------------------------

  /// Open the system folder picker. Returns the persisted tree URI, or null
  /// if the user cancelled.
  static Future<String?> pickTree() =>
      _channel.invokeMethod<String>('pickTree');

  /// Tree URIs the app still holds a persisted read+write grant for.
  static Future<List<String>> persistedTrees() async {
    final list = await _channel.invokeListMethod<String>('persistedTrees');
    return list ?? const [];
  }

  static Future<void> releaseTree(String treeUri) =>
      _channel.invokeMethod('releaseTree', {'treeUri': treeUri});

  static Future<String> treeDisplayName(String treeUri) async {
    final name = await _channel
        .invokeMethod<String>('treeDisplayName', {'treeUri': treeUri});
    return name ?? treeUri;
  }

  /// Whether the app still holds a persisted grant for [treeUri].
  static Future<bool> hasAccess(String treeUri) async {
    final trees = await persistedTrees();
    return trees.contains(treeUri);
  }

  // --- FileStore ----------------------------------------------------------

  @override
  String get rootDescription => displayName;

  @override
  bool get supportsNativeWatch => false;

  @override
  Future<void> ensureDirectory(String relDir) => _invoke('ensureDirectory', {
        'treeUri': treeUri,
        'relDir': normalizeRelPath(relDir),
      });

  @override
  Future<List<StoreEntry>> list(
    String relDir, {
    String extension = '.md',
    bool recursive = false,
  }) async {
    final raw = await _invoke<List<Object?>>('listTree', {
      'treeUri': treeUri,
      'relDir': normalizeRelPath(relDir),
      'extension': extension,
      'recursive': recursive,
    });
    if (raw == null) return const [];
    return raw.map((e) {
      final map = (e as Map).cast<String, Object?>();
      final mtime = map['mtime'] as int?;
      return StoreEntry(
        map['relPath'] as String,
        (mtime == null || mtime == 0)
            ? null
            : DateTime.fromMillisecondsSinceEpoch(mtime),
      );
    }).toList();
  }

  @override
  Future<String?> read(String relPath) => _invoke<String>('readFile', {
        'treeUri': treeUri,
        'relPath': normalizeRelPath(relPath),
      });

  /// One channel call for the whole batch: the Kotlin side resolves each
  /// directory once (a single children query gives every file's document
  /// id) instead of re-scanning the directory per file.
  @override
  Future<Map<String, String?>> readAll(List<String> relPaths) async {
    if (relPaths.isEmpty) return const {};
    final normalized = relPaths.map(normalizeRelPath).toList();
    final raw = await _invoke<Map<Object?, Object?>>('readFiles', {
      'treeUri': treeUri,
      'relPaths': normalized,
    });
    return {
      for (var i = 0; i < relPaths.length; i++)
        relPaths[i]: raw?[normalized[i]] as String?,
    };
  }

  @override
  Future<void> write(String relPath, String content) => _invoke('writeFile', {
        'treeUri': treeUri,
        'relPath': normalizeRelPath(relPath),
        'content': content,
      });

  @override
  Future<void> delete(String relPath) => _invoke('deleteFile', {
        'treeUri': treeUri,
        'relPath': normalizeRelPath(relPath),
      });

  @override
  Future<bool> exists(String relPath) async =>
      await _stat(relPath) != null;

  @override
  Future<DateTime?> modified(String relPath) async {
    final stat = await _stat(relPath);
    final mtime = stat?['mtime'] as int?;
    if (mtime == null || mtime == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(mtime);
  }

  @override
  Future<void> rename(String fromRelPath, String toRelPath) =>
      _invoke('renameFile', {
        'treeUri': treeUri,
        'fromRelPath': normalizeRelPath(fromRelPath),
        'toRelPath': normalizeRelPath(toRelPath),
      });

  @override
  Stream<void>? watchDirectory(String relDir) => null;

  // --- plumbing ------------------------------------------------------------

  Future<Map<Object?, Object?>?> _stat(String relPath) =>
      _invoke<Map<Object?, Object?>>('statFile', {
        'treeUri': treeUri,
        'relPath': normalizeRelPath(relPath),
      });

  /// Invoke with one retry: on failure the Kotlin side drops its directory-id
  /// cache, so a second attempt re-resolves paths from scratch (covers trees
  /// reorganised externally, e.g. by Syncthing).
  Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      Log.w('⚠️ SafFileStore: $method failed (${e.message}), retrying once');
      try {
        return await _channel.invokeMethod<T>(method, args);
      } on PlatformException catch (e2) {
        Log.e('❌ SafFileStore: $method failed after retry', error: e2);
        rethrow;
      }
    }
  }
}
