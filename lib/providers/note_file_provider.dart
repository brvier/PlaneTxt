import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:planova/models/note_file.dart';
import 'package:planova/repositories/note_repository.dart';
import 'package:planova/services/storage_service.dart';
import 'package:planova/services/widget_service.dart';
import 'package:planova/utils/logger.dart';

class NoteFileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  late NoteRepository _noteRepository;

  List<NoteFile> _noteFiles = [];
  Timer? _widgetUpdateTimer;
  static const Duration _widgetUpdateInterval = Duration(minutes: 30);

  // Debounces the home-screen widget push during autosave bursts (500ms).
  Timer? _postSaveWidgetTimer;
  static const Duration _postSaveDebounce = Duration(seconds: 2);

  NoteFileProvider() {
    Log.i('🚀 NoteFileProvider: Constructor called');
    _noteRepository = NoteRepository(_storageService);
  }

  List<NoteFile> get noteFiles => List.unmodifiable(_noteFiles);

  /// Persist the repository disk cache now (e.g. when the app is paused).
  Future<void> persistCache() => _noteRepository.persistCache();

  Future<void> loadNoteFiles({bool forceReload = false}) async {
    Log.i(
        '📝 NoteFileProvider: Loading note files (forceReload: $forceReload)...');
    try {
      _noteFiles = await _noteRepository.loadAll(forceReload: forceReload);
      Log.i('📝 NoteFileProvider: Loaded ${_noteFiles.length} note files');

      // Update widget with recent notes
      await _updateWidget();

      notifyListeners();
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error loading note files', error: e);
      rethrow;
    }
  }

  /// Incremental update - only load modified note files
  Future<void> loadNoteFilesIncremental() async {
    Log.i('📝 NoteFileProvider: Loading incremental note file changes...');
    try {
      _noteFiles = await _noteRepository.loadIncremental();
      Log.i(
          '📝 NoteFileProvider: Incremental load completed, ${_noteFiles.length} total files');

      // Update widget with recent notes
      await _updateWidget();

      notifyListeners();
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error in incremental note file load',
          error: e);
      rethrow;
    }
  }

  Future<void> saveNoteFile(String relativePath, String content) async {
    try {
      Log.d('📝 NoteFileProvider: Saving note file $relativePath');
      final saved = await _noteRepository.create(relativePath, content);

      // Upsert into the in-memory list instead of re-scanning the whole
      // notes directory — this runs on every 500ms autosave. The list is
      // sorted newest-first, and the note just saved is the newest.
      _noteFiles = [
        saved,
        ..._noteFiles.where((n) => n.relativePath != saved.relativePath),
      ];
      notifyListeners();

      _postSaveWidgetTimer?.cancel();
      _postSaveWidgetTimer = Timer(_postSaveDebounce, () {
        unawaited(_updateWidget());
        // Flush the disk cache so a process kill doesn't lose this save
        // from the next startup's fast-paint restore.
        unawaited(_noteRepository.persistCache());
      });

      Log.d('📝 NoteFileProvider: Saved note file $relativePath');
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error saving note file', error: e);
      rethrow;
    }
  }

  Future<bool> renameNoteFile(NoteFile note, String newName) async {
    Log.d('📝 NoteFileProvider: Renaming note ${note.fileName} to $newName');

    // Validate new name
    if (newName.trim().isEmpty) {
      Log.w('📝 NoteFileProvider: New name is empty');
      return false;
    }

    // Clean the new name
    final cleanName =
        newName.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    if (cleanName.isEmpty) {
      Log.w('📝 NoteFileProvider: Cleaned name is empty');
      return false;
    }

    // Create new relative path
    final newRelativePath = note.folderPath.isEmpty
        ? '$cleanName.md'
        : '${note.folderPath}/$cleanName.md';

    try {
      // Check if exists
      final dir = _storageService.notesDirectory;
      if (dir == null) {
        Log.e('❌ NoteFileProvider: Notes directory not initialized');
        return false;
      }

      final newFile = File('${dir.path}/$newRelativePath');
      if (await newFile.exists()) {
        Log.w('📝 NoteFileProvider: File already exists at $newRelativePath');
        return false;
      }

      // Perform rename
      final oldFile = File(note.path);
      await oldFile.rename(newFile.path);

      // Reload notes
      await loadNoteFiles();

      Log.d(
          '📝 NoteFileProvider: Successfully renamed note to $newRelativePath');
      return true;
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error renaming note', error: e);
      return false;
    }
  }

  Future<void> deleteNoteFile(NoteFile noteFile) async {
    try {
      Log.d('📝 NoteFileProvider: Deleting note file ${noteFile.relativePath}');
      await _noteRepository.delete(noteFile);

      // Remove from local list
      _noteFiles.removeWhere((n) => n.path == noteFile.path);

      // Update widget
      await _updateWidget();

      Log.d('📝 NoteFileProvider: Deleted note file ${noteFile.relativePath}');
      notifyListeners();
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error deleting note file', error: e);
      rethrow;
    }
  }

  /// Update widget with recent notes
  Future<void> _updateWidget() async {
    try {
      if (_storageService.orgDirectory == null) {
        Log.d(
            '📱 NoteFileProvider: Skipping widget update - directories not initialized');
        return;
      }

      Log.d('📱 NoteFileProvider: Updating widget with notes');
      await WidgetService.updateWithNotes(_noteFiles);
      Log.i('📱 NoteFileProvider: Widget updated successfully');
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error updating widget', error: e);
    }
  }

  void startWidgetUpdateTimer() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = Timer.periodic(_widgetUpdateInterval, (timer) async {
      Log.d('📱 NoteFileProvider: Periodic widget update triggered');
      try {
        await loadNoteFiles();
        Log.d('📱 NoteFileProvider: Periodic widget update completed');
      } catch (e) {
        Log.e('❌ NoteFileProvider: Error in periodic widget update', error: e);
      }
    });
    Log.i(
        '📱 NoteFileProvider: Started periodic widget update timer (every 30 minutes)');
  }

  @override
  void dispose() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = null;
    _postSaveWidgetTimer?.cancel();
    _postSaveWidgetTimer = null;
    Log.i('📝 NoteFileProvider: Disposed');
    super.dispose();
  }
}
