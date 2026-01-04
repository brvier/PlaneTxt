import 'package:flutter/material.dart';
import 'package:planova/widgets/markdown_editor.dart';

class DailyEditor extends StatefulWidget {
  final String date;
  final String initialContent;
  final Function(String) onSave;
  final Function(String)? onAutoSave;

  const DailyEditor({
    super.key,
    required this.date,
    required this.initialContent,
    required this.onSave,
    this.onAutoSave,
  });

  @override
  State<DailyEditor> createState() => DailyEditorState();
}

class DailyEditorState extends State<DailyEditor> {
  @override
  Widget build(BuildContext context) {
    return MarkdownEditor(
      initialContent: widget.initialContent,
      onSave: widget.onSave,
      onAutoSave: widget.onAutoSave,
      title: 'Daily Notes - ${_formatDate(widget.date)}',
      hintText:
          'Write your daily notes here...\\n\\nYou can use Markdown syntax:\\n- **bold** for bold text\\n- *italic* for italic text\\n- - for bullet lists\\n- 1. for numbered lists\\n- [ ] for todo items',
      mode: EditorMode.embedded,
      showHeaderButton: false,
      showCodeButton: false,
      showToggleTodo: true,
      showSaveButton: true,
    );
  }

  void saveBeforeSwitch() {
    // This will be handled by the parent widget
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
