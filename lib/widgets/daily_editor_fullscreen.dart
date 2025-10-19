import 'package:flutter/material.dart';
import 'dart:async';

class DailyEditorFullscreen extends StatefulWidget {
  final String date;
  final String initialContent;
  final Function(String) onSave;
  final Function(String)? onAutoSave;

  const DailyEditorFullscreen({
    super.key,
    required this.date,
    required this.initialContent,
    required this.onSave,
    this.onAutoSave,
  });

  @override
  State<DailyEditorFullscreen> createState() => DailyEditorFullscreenState();
}

class DailyEditorFullscreenState extends State<DailyEditorFullscreen> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  Timer? _autoSaveTimer;
  String _savedContent = '';

  @override
  void initState() {
    super.initState();
    _savedContent = widget.initialContent;
    _controller = TextEditingController(text: widget.initialContent);
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
        title: Text('Daily Notes - ${_formatDate(widget.date)}'),
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
                  onPressed: _toggleTodo,
                  icon: const Icon(Icons.check_box),
                  tooltip: 'Toggle Todo',
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
                hintText: 'Write your daily notes here...\n\nYou can use Markdown syntax:\n# Header\n**bold** *italic*\n- bullet list\n1. numbered list\n[ ] todo item',
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
        const SnackBar(content: Text('Daily notes saved')),
      );
    }
  }

  void _toggleTodo() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (!selection.isValid) return;
    
    // Find the current line
    final lines = text.split('\n');
    int currentLine = 0;
    int currentPosition = 0;
    
    for (int i = 0; i < lines.length; i++) {
      final lineLength = lines[i].length + 1; // +1 for newline
      if (currentPosition + lineLength > selection.start) {
        currentLine = i;
        break;
      }
      currentPosition += lineLength;
    }
    
    if (currentLine >= lines.length) return;
    
    final currentLineText = lines[currentLine];
    
    // Check if this line has a todo checkbox
    final todoMatch = RegExp(r'^(\s*[-*+]\s*)\[\s*([x\s])\s*\]\s*(.*)$').firstMatch(currentLineText);
    
    if (todoMatch != null) {
      // Toggle the checkbox
      final prefix = todoMatch.group(1)!;
      final isChecked = todoMatch.group(2) == 'x';
      final content = todoMatch.group(3)!;
      
      final newCheckbox = isChecked ? '[ ]' : '[x]';
      final newLine = '$prefix$newCheckbox $content';
      
      // Replace the line
      lines[currentLine] = newLine;
      final newText = lines.join('\n');
      
      // Calculate new cursor position
      final newCursorPosition = currentPosition + newLine.length;
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    } else {
      // If no todo checkbox, insert a new todo item
      final indent = currentLineText.replaceAll(RegExp(r'^(\s*).*$'), r'$1');
      final newTodo = '${indent}- [ ] ';
      
      // Insert at the beginning of the line
      final newLine = newTodo + currentLineText.trim();
      lines[currentLine] = newLine;
      final newText = lines.join('\n');
      
      // Calculate new cursor position
      final newCursorPosition = currentPosition + newTodo.length;
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    }
  }

  String _formatDate(String dateString) {
    if (dateString.length == 8) {
      final year = dateString.substring(0, 4);
      final month = dateString.substring(4, 6);
      final day = dateString.substring(6, 8);
      return '$day/$month/$year';
    }
    return dateString;
  }
}