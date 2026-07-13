/// Storage backend abstraction.
///
/// All Planova user files (dailies, notes, archives) live under a single
/// storage root. A [FileStore] addresses them by POSIX-style paths relative
/// to that root (e.g. `dailies/20260713.md`), never by absolute paths, so
/// the same repository/provider code works over:
///  - a raw filesystem directory ([IoFileStore]) - app-private dir, desktop,
///    iOS, or any directly writable path;
///  - an Android Storage Access Framework document tree ([SafFileStore]) -
///    a user-selected folder (Syncthing, Dropbox, …) accessed through a
///    persisted URI grant, with no storage permission.
library;

/// A file inside a [FileStore], as returned by [FileStore.list].
class StoreEntry {
  /// Path relative to the store root, `/`-separated (e.g. `notes/a/b.md`).
  final String relPath;

  /// Last modification time, if the backend provides it.
  final DateTime? modified;

  const StoreEntry(this.relPath, this.modified);

  @override
  String toString() => 'StoreEntry($relPath, $modified)';
}

abstract class FileStore {
  /// Human-readable description of the root, for the preferences UI.
  String get rootDescription;

  /// Whether [watchDirectory] emits native filesystem events. When `false`,
  /// callers must poll [list] and diff mtimes themselves.
  bool get supportsNativeWatch;

  /// Create [relDir] (and parents) if missing.
  Future<void> ensureDirectory(String relDir);

  /// List files under [relDir] whose name ends with [extension].
  Future<List<StoreEntry>> list(
    String relDir, {
    String extension = '.md',
    bool recursive = false,
  });

  /// File content, or `null` when the file does not exist.
  Future<String?> read(String relPath);

  /// Contents of several files in one pass, keyed by the input paths.
  /// Missing files map to `null`. Backends override this when bulk access
  /// is much cheaper than per-file reads (SAF: one directory query serves
  /// every file in that directory).
  Future<Map<String, String?>> readAll(List<String> relPaths) async {
    final results = await Future.wait(relPaths.map(read));
    return {
      for (var i = 0; i < relPaths.length; i++) relPaths[i]: results[i],
    };
  }

  /// Write [content] to [relPath], creating parent directories as needed.
  Future<void> write(String relPath, String content);

  Future<void> delete(String relPath);

  Future<bool> exists(String relPath);

  /// Last modification time, or `null` when the file does not exist.
  Future<DateTime?> modified(String relPath);

  /// Rename/move a file within the store.
  Future<void> rename(String fromRelPath, String toRelPath);

  /// Native change events for [relDir], or `null` when unsupported
  /// (see [supportsNativeWatch]).
  Stream<void>? watchDirectory(String relDir);
}

/// Normalises a relative path: collapses `//`, strips leading/trailing `/`.
/// Throws [ArgumentError] on `..` segments so a crafted name can never
/// escape the store root.
String normalizeRelPath(String relPath) {
  final parts = relPath
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty && s != '.')
      .toList();
  if (parts.any((s) => s == '..')) {
    throw ArgumentError.value(relPath, 'relPath', 'must not contain ..');
  }
  return parts.join('/');
}
