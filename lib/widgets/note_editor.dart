import 'package:flutter/material.dart';
import 'package:planova/models/note_file.dart';
import 'package:planova/widgets/markdown_editor.dart';

class NoteEditor extends StatefulWidget {
  final NoteFile note;
  final Future<void> Function(String) onSave;
  final Future<void> Function(String)? onAutoSave;

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
  @override
  Widget build(BuildContext context) {
    return MarkdownEditor(
      initialContent: widget.note.content,
      onSave: widget.onSave,
      onAutoSave: widget.onAutoSave,
      title: widget.note.displayName,
      hintText:
          'Write your note here...\\n\\nYou can use Markdown syntax:\\n# Header\\n**bold** *italic*\\n- bullet list\\n1. numbered list\\n[ ] todo item',
      mode: EditorMode.fullscreen,
      showHeaderButton: true,
      showCodeButton: true,
      showToggleTodo: true, // Same as fullscreen daily editor
      showSaveButton: true,
      saveSuccessMessage: 'Note saved',
    );
  }

  void saveBeforeSwitch() {
    // This will be handled by the parent widget
  }
}
