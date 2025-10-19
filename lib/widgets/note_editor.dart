import 'package:flutter/material.dart';
import 'dart:async';
import '../models/note_file.dart';

class NoteEditor extends StatefulWidget {
  final NoteFile note;
  final Function(String) onSave;
  final Function(String)? onAutoSave;

  const NoteEditor({
    super.key,
    required this.note,
    required this.onSave,
    this.onAutoSave,
  });

  @override
  State<NoteEditor> createState() => NoteEditorState();
}

class NoteEditorState extends State<NoteEditor> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  Timer? _autoSaveTimer;
  String _savedContent = '';

  @override
  void initState() {
    super.initState();
    _savedContent = widget.note.content;
    _controller = TextEditingController(text: widget.note.content);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = _controller.text != _savedContent;
    });

    // Cancel previous timer
    _autoSaveTimer?.cancel();
    
    // Start new timer for autosave
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (widget.onAutoSave != null && _hasChanges) {
        widget.onAutoSave!(_controller.text);
        // Update the saved content to reflect the saved state
        setState(() {
          _savedContent = _controller.text;
          _hasChanges = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void saveBeforeSwitch() {
    if (_hasChanges && widget.onAutoSave != null) {
      widget.onAutoSave!(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.displayName),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveContent,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _insertText,
                  icon: const Icon(Icons.format_bold),
                  tooltip: 'Bold',
                ),
                IconButton(
                  onPressed: () => _insertText('*', '*'),
                  icon: const Icon(Icons.format_italic),
                  tooltip: 'Italic',
                ),
                IconButton(
                  onPressed: () => _insertText('# '),
                  icon: const Icon(Icons.title),
                  tooltip: 'Header',
                ),
                IconButton(
                  onPressed: () => _insertText('- '),
                  icon: const Icon(Icons.format_list_bulleted),
                  tooltip: 'Bullet List',
                ),
                IconButton(
                  onPressed: () => _insertText('1. '),
                  icon: const Icon(Icons.format_list_numbered),
                  tooltip: 'Numbered List',
                ),
                IconButton(
                  onPressed: () => _insertText('[ ] '),
                  icon: const Icon(Icons.check_box_outline_blank),
                  tooltip: 'Todo Item',
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _insertText('`', '`'),
                  icon: const Icon(Icons.code),
                  tooltip: 'Code',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Text editor
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Write your note here...\n\nYou can use Markdown syntax:\n# Header\n**bold** *italic*\n- bullet list\n1. numbered list\n[ ] todo item',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _insertText([String prefix = '', String suffix = '']) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.isValid) {
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix${selection.textInside(text)}$suffix',
      );
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length + selection.textInside(text).length + suffix.length,
        ),
      );
    }
  }

  void _saveContent() {
    widget.onSave(_controller.text);
    setState(() {
      _savedContent = _controller.text;
      _hasChanges = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    }
  }
}