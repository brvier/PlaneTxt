import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum EditorMode {
  embedded, // For use within other widgets (like DailyEditor)
  fullscreen, // For full-screen editing (like NoteEditor, DailyEditorFullscreen)
}

class MarkdownEditor extends StatefulWidget {
  final String initialContent;
  final Function(String) onSave;
  final Function(String)? onAutoSave;
  final String title;
  final String hintText;
  final EditorMode mode;
  final bool showHeaderButton;
  final bool showCodeButton;
  final bool showToggleTodo;
  final bool showSaveButton;
  final String? saveSuccessMessage;

  const MarkdownEditor({
    super.key,
    required this.initialContent,
    required this.onSave,
    this.onAutoSave,
    required this.title,
    required this.hintText,
    this.mode = EditorMode.embedded,
    this.showHeaderButton = true,
    this.showCodeButton = true,
    this.showToggleTodo = true,
    this.showSaveButton = true,
    this.saveSuccessMessage,
  });

  @override
  State<MarkdownEditor> createState() => MarkdownEditorState();
}

class MarkdownEditorState extends State<MarkdownEditor> {
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
    final editorContent = Column(
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
              if (widget.showHeaderButton)
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
              if (widget.showToggleTodo)
                IconButton(
                  onPressed: _toggleTodo,
                  icon: const Icon(Icons.check_box),
                  tooltip: 'Toggle Todo',
                )
              else
                IconButton(
                  onPressed: () => _insertText('[ ] '),
                  icon: const Icon(Icons.check_box_outline_blank),
                  tooltip: 'Todo Item',
                ),
              IconButton(
                onPressed: _showDateTimeDialog,
                icon: const Icon(Icons.access_time),
                tooltip: 'Insert Date & Time',
              ),
              const Spacer(),
              if (widget.showCodeButton)
                IconButton(
                  onPressed: () => _insertText('`', '`'),
                  icon: const Icon(Icons.code),
                  tooltip: 'Code',
                ),
              if (widget.showSaveButton &&
                  widget.mode == EditorMode.embedded &&
                  _hasChanges)
                TextButton(
                  onPressed: _saveContent,
                  child: const Text('Save'),
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
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            inputFormatters: [
              _MarkdownInputFormatter(),
            ],
          ),
        ),
      ],
    );

    if (widget.mode == EditorMode.fullscreen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _saveContent,
                child: const Text('Save'),
              ),
          ],
        ),
        body: editorContent,
      );
    } else {
      return editorContent;
    }
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
          offset: selection.start +
              prefix.length +
              selection.textInside(text).length +
              suffix.length,
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
    if (widget.mode == EditorMode.fullscreen && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.saveSuccessMessage ?? 'Content saved')),
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
    final todoMatch = RegExp(r'^(\s*[-*+]\s*)\[\s*([x\s])\s*\]\s*(.*)$')
        .firstMatch(currentLineText);

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
      final indentMatch = RegExp(r'^(\s*)').firstMatch(currentLineText);
      final indent = indentMatch?.group(1) ?? '';
      final newTodo = '$indent- [ ] ';

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

  String _formatTime24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showDateTimeDialog() {
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Insert Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select time:'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        selectedTime = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(_formatTime24Hour(selectedTime)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.preview, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Preview: @${_formatTime24Hour(selectedTime)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final timeStr = _formatTime24Hour(selectedTime);
                _insertText('@$timeStr ');
                Navigator.of(context).pop();
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Check if this is an Enter key press (newline added)
    if (newValue.text.length > oldValue.text.length) {
      // Find the difference - check if a newline was just added
      final oldLines = oldValue.text.split('\n');
      final newLines = newValue.text.split('\n');

      if (newLines.length > oldLines.length) {
        // A newline was added, find which line was split
        final text = newValue.text;
        final selection = newValue.selection;

        if (!selection.isValid) return newValue;

        // Find the current line (the one with the cursor)
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

        if (currentLine >= lines.length) return newValue;

        // Get the previous line (the one that was split)
        final previousLineIndex = currentLine - 1;
        if (previousLineIndex < 0) return newValue;

        final previousLineText = lines[previousLineIndex];

        // Check for patterns that should be continued
        final patterns = [
          RegExp(
              r'^(\s*)(-\s+\[[x\s]\]\s+)(.*)$'), // - [x] or - [ ] item (check this first)
          RegExp(r'^(\s*)(-\s+@\d{2}:\d{2}\s+)(.*)$'), // - @14:00 item
          RegExp(r'^(\s*)(-\s+)(.*)$'), // - item (check this last)
        ];

        String? indent;
        String? prefix;

        for (final pattern in patterns) {
          final match = pattern.firstMatch(previousLineText);
          if (match != null) {
            indent = match.group(1) ?? '';
            prefix = match.group(2) ?? '';
            break;
          }
        }

        if (indent != null && prefix != null) {
          // Insert new line with the same indentation and prefix
          final newLine = '$indent$prefix';
          final newText = text.replaceRange(
            selection.start,
            selection.end,
            newLine,
          );

          return TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: selection.start + newLine.length,
            ),
          );
        }
      }
    }

    return newValue;
  }
}
