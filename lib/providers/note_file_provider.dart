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

  NoteFileProvider() {
    Log.i('🚀 NoteFileProvider: Constructor called');
    _noteRepository = NoteRepository(_storageService);
  }

  List<NoteFile> get noteFiles => List.unmodifiable(_noteFiles);

  Future<void> loadNoteFiles() async {
    Log.i('📝 NoteFileProvider: Loading note files...');
    try {
      _noteFiles = await _noteRepository.loadAll();
      Log.i('📝 NoteFileProvider: Loaded ${_noteFiles.length} note files');

      // Update widget with recent notes
      await _updateWidget();

      notifyListeners();
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error loading note files', e);
      rethrow;
    }
  }

  Future<void> saveNoteFile(String relativePath, String content) async {
    try {
      Log.d('📝 NoteFileProvider: Saving note file $relativePath');
      await _noteRepository.create(relativePath, content);

      // Reload notes to ensure correct order and metadata
      await loadNoteFiles();

      Log.d('📝 NoteFileProvider: Saved note file $relativePath');
    } catch (e) {
      Log.e('❌ NoteFileProvider: Error saving note file', e);
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
      Log.e('❌ NoteFileProvider: Error renaming note', e);
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
      Log.e('❌ NoteFileProvider: Error deleting note file', e);
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
      Log.e('❌ NoteFileProvider: Error updating widget', e);
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
        Log.e('❌ NoteFileProvider: Error in periodic widget update', e);
      }
    });
    Log.i(
        '📱 NoteFileProvider: Started periodic widget update timer (every 30 minutes)');
  }

  @override
  void dispose() {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = null;
    Log.i('📝 NoteFileProvider: Disposed');
    super.dispose();
  }
}
