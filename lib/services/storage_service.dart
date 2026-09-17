import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:planetxt/services/file_store/file_store.dart';
import 'package:planetxt/services/file_store/io_file_store.dart';
import 'package:planetxt/services/file_store/saf_file_store.dart';
import 'package:planetxt/utils/logger.dart';

export 'package:planetxt/services/file_store/file_store.dart'
    show FileStore, StoreEntry;

/// Owns the active [FileStore] (the user's storage root) and the app-private
/// location used for disk caches.
///
/// Storage roots, by priority:
///  1. SAF document tree (Android custom folder - Syncthing, Dropbox, …),
///     addressed through a persisted URI grant, no storage permission;
///  2. raw custom path (desktop);
///  3. default: `<app documents>/Org` (private, no permission).
///
/// All user files are addressed by store-relative paths such as
/// `dailies/20260713.md` or `notes/projects/planetxt.md`.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String dailiesDirName = 'dailies';
  static const String archivesDirName = 'archives';
  static const String notesDirName = 'notes';

  FileStore? _store;
  Directory? _privateRoot;

  /// Set when a configured SAF tree is no longer accessible (grant revoked,
  /// folder deleted). The UI should prompt the user to pick the folder again.
  bool storageAccessLost = false;

  FileStore? get store => _store;
  bool get isInitialized => _store != null;

  /// Human-readable description of the active storage root.
  String get storageDescription =>
      _store?.rootDescription ?? 'Not initialized';

  /// Relative daily file path for a YYYYMMDD [date].
  static String dailyPath(String date) => '$dailiesDirName/$date.md';

  /// Relative note path for a path relative to the notes directory.
  static String notePath(String relativeToNotes) =>
      '$notesDirName/${normalizeRelPath(relativeToNotes)}';

  Future<void> initializeDirectories({
    String? customPath,
    String? safTreeUri,
    String? safDisplayName,
  }) async {
    Log.i('📁 StorageService: Initializing storage root...');
    _privateRoot ??= await getApplicationDocumentsDirectory();
    storageAccessLost = false;

    if (safTreeUri != null) {
      if (await _safAccessible(safTreeUri)) {
        _store = SafFileStore(safTreeUri, displayName: safDisplayName);
      } else {
        Log.e('❌ StorageService: Lost access to SAF tree $safTreeUri');
        storageAccessLost = true;
        _store = _defaultStore();
      }
    } else if (customPath != null) {
      final dir = Directory(customPath);
      if (await dir.exists() && await _isWritable(dir)) {
        _store = IoFileStore(dir);
      } else {
        Log.e('❌ StorageService: Custom path not writable: $customPath');
        storageAccessLost = true;
        _store = _defaultStore();
      }
    } else {
      _store = _defaultStore();
    }

    try {
      await _store!.ensureDirectory(dailiesDirName);
      await _store!.ensureDirectory(archivesDirName);
      await _store!.ensureDirectory(notesDirName);
    } catch (e) {
      Log.e('❌ StorageService: Cannot create base directories, '
          'falling back to default root', error: e);
      storageAccessLost = true;
      _store = _defaultStore();
      await _store!.ensureDirectory(dailiesDirName);
      await _store!.ensureDirectory(archivesDirName);
      await _store!.ensureDirectory(notesDirName);
    }

    await _cleanupLegacyCaches();
    Log.i('📁 StorageService: Storage root ready '
        '(${_store!.rootDescription})');
  }

  IoFileStore _defaultStore() =>
      IoFileStore(Directory('${_privateRoot!.path}/Org'));

  Future<bool> _safAccessible(String treeUri) async {
    try {
      return await SafFileStore.hasAccess(treeUri);
    } catch (e) {
      Log.e('❌ StorageService: SAF access check failed', error: e);
      return false;
    }
  }

  Future<bool> _isWritable(Directory dir) async {
    try {
      final testFile = File('${dir.path}/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Repository disk caches live in the app-private directory: always
  /// directly writable, never synced to the user's folder by tools like
  /// Syncthing, and safe to read/write from isolates with plain dart:io.
  String cacheFilePath(String cacheFileName) =>
      '${_privateRoot!.path}/$cacheFileName';

  /// Older versions wrote repository caches inside the user's Org folder.
  /// Remove them so they stop being synced around (best effort, io roots
  /// only - SAF trees never received them).
  Future<void> _cleanupLegacyCaches() async {
    final store = _store;
    if (store is! IoFileStore) return;
    for (final name in ['._daily_cache.json', '._note_cache.json']) {
      try {
        final legacy = File('${store.root.path}/$name');
        if (await legacy.exists()) await legacy.delete();
      } catch (_) {}
    }
  }
}
