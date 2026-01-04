class CalendarEvent {
  final String title;
  final DateTime time;
  final String description;
  final String date; // YYYYMMDD format

  CalendarEvent({
    required this.title,
    required this.time,
    required this.description,
    required this.date,
  });

  String get formattedTime {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get displayTitle {
    // Remove the @HH:MM part from the title
    String cleaned = title.replaceAll(RegExp(r'@\d{1,2}:\d{2}'), '').trim();
    // Remove markdown list markers (-, *, +) from the beginning
    cleaned = cleaned.replaceFirst(RegExp(r'^[-*+]\s+'), '').trim();
    return cleaned;
  }

  CalendarEvent copyWith({
    String? title,
    DateTime? time,
    String? description,
    String? date,
  }) {
    return CalendarEvent(
      title: title ?? this.title,
      time: time ?? this.time,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }
}
