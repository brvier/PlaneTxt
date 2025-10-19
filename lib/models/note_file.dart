class NoteFile {
  final String path;
  final String relativePath;
  final String content;
  final DateTime lastModified;

  NoteFile({
    required this.path,
    required this.relativePath,
    required this.content,
    required this.lastModified,
  });

  String get fileName {
    return relativePath.split('/').last.replaceAll('.md', '');
  }

  String get folderPath {
    final parts = relativePath.split('/');
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join('/');
    }
    return '';
  }

  String get displayName {
    return fileName.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  NoteFile copyWith({
    String? path,
    String? relativePath,
    String? content,
    DateTime? lastModified,
  }) {
    return NoteFile(
      path: path ?? this.path,
      relativePath: relativePath ?? this.relativePath,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}