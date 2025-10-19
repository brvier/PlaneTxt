import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../models/note_file.dart';
import '../widgets/note_editor.dart';
import '../widgets/note_list_item.dart';

class NotesView extends StatefulWidget {
  const NotesView({super.key});

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        final filteredNotes = _filterNotes(fileProvider.noteFiles);
        
        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Notes list
            Expanded(
              child: filteredNotes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        return NoteListItem(
                          note: note,
                          onTap: () => _openNote(note),
                          onRename: () => _renameNote(note),
                          onDelete: () => _deleteNote(note),
                        );
                      },
                    ),
            ),
            
            // Add note button
            Padding(
              padding: const EdgeInsets.all(16),
              child: FloatingActionButton.extended(
                onPressed: _addNote,
                icon: const Icon(Icons.add),
                label: const Text('Add Note'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No notes yet' : 'No notes found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty 
                ? 'Tap the + button to create your first note'
                : 'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  List<NoteFile> _filterNotes(List<NoteFile> notes) {
    if (_searchQuery.isEmpty) return notes;
    
    return notes.where((note) {
      return note.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             note.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _addNote() {
    showDialog(
      context: context,
      builder: (context) => _AddNoteDialog(),
    );
  }

  void _openNote(NoteFile note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteEditor(
          note: note,
          onSave: (content) {
            context.read<FileProvider>().saveNoteFile(note.relativePath, content);
          },
          onAutoSave: (content) {
            context.read<FileProvider>().saveNoteFile(note.relativePath, content);
            // Don't show snackbar for autosave
          },
        ),
      ),
    );
  }

  void _renameNote(NoteFile note) {
    showDialog(
      context: context,
      builder: (context) => _RenameNoteDialog(note: note),
    );
  }

  void _deleteNote(NoteFile note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement delete functionality
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _nameController = TextEditingController();
  final _folderController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Note Name',
              hintText: 'Enter note name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _folderController,
            decoration: const InputDecoration(
              labelText: 'Folder (optional)',
              hintText: 'e.g., Work, Personal',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _createNote,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _createNote() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final folder = _folderController.text.trim();
    final relativePath = folder.isEmpty ? '$name.md' : '$folder/$name.md';
    
    context.read<FileProvider>().saveNoteFile(relativePath, '');
    Navigator.of(context).pop();
  }
}

class _RenameNoteDialog extends StatefulWidget {
  final NoteFile note;

  const _RenameNoteDialog({required this.note});

  @override
  State<_RenameNoteDialog> createState() => _RenameNoteDialogState();
}

class _RenameNoteDialogState extends State<_RenameNoteDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.note.fileName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Note'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Note Name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _renameNote,
          child: const Text('Rename'),
        ),
      ],
    );
  }

  void _renameNote() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == widget.note.fileName) return;

    final fileProvider = Provider.of<FileProvider>(context, listen: false);
    final success = await fileProvider.renameNoteFile(widget.note, newName);
    
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note renamed to "$newName"')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to rename note. A file with that name may already exist.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}