import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/daily_file.dart';
import '../models/note_file.dart';
import '../models/calendar_event.dart';
import 'theme_provider.dart';

class FileProvider extends ChangeNotifier {
  Directory? _documentsDirectory;
  Directory? _orgDirectory;
  Directory? _dailiesDirectory;
  Directory? _archivesDirectory;
  Directory? _notesDirectory;

  List<DailyFile> _dailyFiles = [];
  List<NoteFile> _noteFiles = [];
  String _selectedDate = '';

  Directory? get documentsDirectory => _documentsDirectory;
  Directory? get orgDirectory => _orgDirectory;
  Directory? get dailiesDirectory => _dailiesDirectory;
  Directory? get archivesDirectory => _archivesDirectory;
  Directory? get notesDirectory => _notesDirectory;

  List<DailyFile> get dailyFiles => _dailyFiles;
  List<NoteFile> get noteFiles => _noteFiles;
  String get selectedDate => _selectedDate;

  Future<void> initializeDirectories(BuildContext context) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    // Use custom storage path if set, otherwise use default documents directory
    if (themeProvider.customStoragePath != null) {
      // Use the custom path directly as the root directory
      _orgDirectory = Directory(themeProvider.customStoragePath!);
    } else {
      _documentsDirectory = await getApplicationDocumentsDirectory();
      _orgDirectory = Directory('${_documentsDirectory!.path}/Org');
    }
    
    _dailiesDirectory = Directory('${_orgDirectory!.path}/dailies');
    _archivesDirectory = Directory('${_orgDirectory!.path}/archives');
    _notesDirectory = Directory('${_orgDirectory!.path}/notes');

    // Create directories if they don't exist
    await _orgDirectory!.create(recursive: true);
    await _dailiesDirectory!.create(recursive: true);
    await _archivesDirectory!.create(recursive: true);
    await _notesDirectory!.create(recursive: true);

    await loadDailyFiles();
    await loadNoteFiles();
    notifyListeners();
  }

  Future<void> loadDailyFiles() async {
    if (_dailiesDirectory == null) return;

    _dailyFiles.clear();
    final files = _dailiesDirectory!.listSync()
        .where((file) => file is File && file.path.endsWith('.md'))
        .cast<File>();

    for (final file in files) {
      final content = await file.readAsString();
      final fileName = file.path.split('/').last;
      final date = fileName.replaceAll('.md', '');
      
      _dailyFiles.add(DailyFile(
        path: file.path,
        date: date,
        content: content,
      ));
    }

    _dailyFiles.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> loadNoteFiles() async {
    if (_notesDirectory == null) return;

    _noteFiles.clear();
    await _loadNotesRecursively(_notesDirectory!);
    notifyListeners();
  }

  Future<void> _loadNotesRecursively(Directory directory) async {
    final files = directory.listSync();
    
    for (final file in files) {
      if (file is Directory) {
        await _loadNotesRecursively(file);
      } else if (file is File && file.path.endsWith('.md')) {
        final content = await file.readAsString();
        final relativePath = file.path.replaceFirst('${_notesDirectory!.path}/', '');
        
        _noteFiles.add(NoteFile(
          path: file.path,
          relativePath: relativePath,
          content: content,
        ));
      }
    }
  }

  Future<void> saveDailyFile(String date, String content) async {
    if (_dailiesDirectory == null) return;

    final file = File('${_dailiesDirectory!.path}/$date.md');
    await file.writeAsString(content);

    // Update or add to daily files list
    final existingIndex = _dailyFiles.indexWhere((d) => d.date == date);
    if (existingIndex != -1) {
      _dailyFiles[existingIndex] = DailyFile(
        path: file.path,
        date: date,
        content: content,
      );
    } else {
      _dailyFiles.add(DailyFile(
        path: file.path,
        date: date,
        content: content,
      ));
      _dailyFiles.sort((a, b) => b.date.compareTo(a.date));
    }

    notifyListeners();
  }

  Future<void> saveNoteFile(String relativePath, String content) async {
    if (_notesDirectory == null) return;

    final file = File('${_notesDirectory!.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    // Update or add to note files list
    final existingIndex = _noteFiles.indexWhere((n) => n.relativePath == relativePath);
    if (existingIndex != -1) {
      _noteFiles[existingIndex] = NoteFile(
        path: file.path,
        relativePath: relativePath,
        content: content,
      );
    } else {
      _noteFiles.add(NoteFile(
        path: file.path,
        relativePath: relativePath,
        content: content,
      ));
    }

    notifyListeners();
  }

  Future<bool> renameNoteFile(NoteFile note, String newName) async {
    if (_notesDirectory == null) return false;

    // Validate new name
    if (newName.trim().isEmpty) return false;
    
    // Clean the new name (replace spaces with underscores, remove special characters)
    final cleanName = newName.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    if (cleanName.isEmpty) return false;

    // Create new relative path
    final newRelativePath = note.folderPath.isEmpty 
        ? '$cleanName.md'
        : '${note.folderPath}/$cleanName.md';

    // Check if a file with the new name already exists
    final existingFile = File('${_notesDirectory!.path}/$newRelativePath');
    if (await existingFile.exists()) return false;

    try {
      // Rename the physical file
      final oldFile = File(note.path);
      await oldFile.rename(existingFile.path);

      // Update the note in the list
      final noteIndex = _noteFiles.indexWhere((n) => n.path == note.path);
      if (noteIndex != -1) {
        _noteFiles[noteIndex] = NoteFile(
          path: existingFile.path,
          relativePath: newRelativePath,
          content: note.content,
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error renaming note: $e');
    }

    return false;
  }

  void setSelectedDate(String date) {
    _selectedDate = date;
    notifyListeners();
  }

  DailyFile? getDailyFile(String date) {
    try {
      return _dailyFiles.firstWhere((d) => d.date == date);
    } catch (e) {
      return null;
    }
  }

  String getTodayDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  bool hasUndoneTodos(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;
    
    // Check for undone todos in markdown format: [ ] task
    final undoneTodoPattern = RegExp(r'^\s*-\s*\[\s*\]\s+', multiLine: true);
    return undoneTodoPattern.hasMatch(dailyFile.content);
  }

  bool hasTodos(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return false;
    
    // Check for any todos (done or undone): [ ] or [x] task
    final todoPattern = RegExp(r'^\s*-\s*\[\s*[x\s]\s*\]\s+', multiLine: true);
    return todoPattern.hasMatch(dailyFile.content);
  }

  int getUndoneTodoCount(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return 0;
    
    // Count undone todos
    final undoneTodoPattern = RegExp(r'^\s*-\s*\[\s*\]\s+', multiLine: true);
    return undoneTodoPattern.allMatches(dailyFile.content).length;
  }

  List<CalendarEvent> getCalendarEvents(String date) {
    final dailyFile = getDailyFile(date);
    if (dailyFile == null || dailyFile.content.isEmpty) return [];

    final events = <CalendarEvent>[];
    final lines = dailyFile.content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final timeMatch = RegExp(r'@(\d{1,2}):(\d{2})').firstMatch(line);
      
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        
        // Parse the date from the date string (YYYYMMDD format)
        final year = int.parse(date.substring(0, 4));
        final month = int.parse(date.substring(4, 6));
        final day = int.parse(date.substring(6, 8));
        
        final eventTime = DateTime(year, month, day, hour, minute);
        
        // Extract the event title (everything after @HH:MM)
        final title = line.replaceAll(RegExp(r'@\d{1,2}:\d{2}'), '').trim();
        
        // Look for description in the next few lines (until next time marker or empty line)
        final description = _extractEventDescription(lines, i);
        
        events.add(CalendarEvent(
          title: title,
          time: eventTime,
          description: description,
          date: date,
        ));
      }
    }
    
    // Sort events by time
    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  String _extractEventDescription(List<String> lines, int startIndex) {
    final description = StringBuffer();
    
    for (int i = startIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      
      // Stop if we hit another time marker or empty line
      if (line.trim().isEmpty || RegExp(r'@\d{1,2}:\d{2}').hasMatch(line)) {
        break;
      }
      
      // Skip markdown list markers and add the line
      final cleanLine = line.replaceAll(RegExp(r'^\s*[-*+]\s*'), '').trim();
      if (cleanLine.isNotEmpty) {
        if (description.isNotEmpty) {
          description.write('\n');
        }
        description.write(cleanLine);
      }
    }
    
    return description.toString();
  }

  bool hasCalendarEvents(String date) {
    return getCalendarEvents(date).isNotEmpty;
  }
}