class DailyFile {
  final String path;
  final String date;
  final String content;

  DailyFile({
    required this.path,
    required this.date,
    required this.content,
  });

  DateTime get dateTime {
    final year = int.parse(date.substring(0, 4));
    final month = int.parse(date.substring(4, 6));
    final day = int.parse(date.substring(6, 8));
    return DateTime(year, month, day);
  }

  String get formattedDate {
    final dt = dateTime;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  DailyFile copyWith({
    String? path,
    String? date,
    String? content,
  }) {
    return DailyFile(
      path: path ?? this.path,
      date: date ?? this.date,
      content: content ?? this.content,
    );
  }
}