import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/file_provider.dart';
import '../providers/theme_provider.dart';
import '../models/daily_file.dart';
import '../models/calendar_event.dart';
import '../widgets/daily_editor_fullscreen.dart';
import '../widgets/calendar_day_widget.dart';
import '../widgets/quick_add_modal.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        return Column(
          children: [
            // Calendar - Uses its intrinsic size
            Container(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 0), // Remove bottom padding
              child: TableCalendar<DailyFile>(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _loadDailyContent(selectedDay);
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  eventLoader: (day) {
                    // We're using custom day builders instead of events
                    return [];
                  },
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    markersMaxCount: 0, // We'll use custom day builder instead
                    cellPadding:
                        EdgeInsets.zero, // Remove internal cell padding
                    cellMargin: EdgeInsets.zero, // Remove internal cell margin
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCustomDay(
                          context, day, focusedDay, fileProvider);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return _buildCustomDay(
                          context, day, focusedDay, fileProvider,
                          isSelected: true);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildCustomDay(
                          context, day, focusedDay, fileProvider,
                          isToday: true);
                    },
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    leftChevronPadding:
                        EdgeInsets.zero, // Remove header padding
                    rightChevronPadding:
                        EdgeInsets.zero, // Remove header padding
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontSize: 12), // Smaller day labels
                    weekendStyle: TextStyle(fontSize: 12), // Smaller day labels
                  ),
                ),
            ),

            // Daily content - Takes remaining space with flex
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                    16, 0, 16, 16), // Remove top padding
                child: _selectedDay != null
                    ? SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: _buildDailyContent(fileProvider),
                      )
                    : const Center(
                        child: Text('Select a day to view content'),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDailyContent(FileProvider fileProvider) {
    final dateString = _formatDate(_selectedDay!);
    final dailyFile = fileProvider.getDailyFile(dateString);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final initialContent = dailyFile?.content ?? themeProvider.dailyTemplate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () => _showQuickAddModal(context, fileProvider),
              icon: const Icon(Icons.add),
              tooltip: 'Quick add event or todo',
            ),
            IconButton(
              onPressed: () => _openDailyEditor(
                  context, fileProvider, dateString, initialContent),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit daily notes',
            ),
            IconButton(
              onPressed: () =>
                  _showRefileDialog(context, fileProvider, dateString),
              icon: const Icon(Icons.move_to_inbox),
              tooltip: 'Refile items to another day',
            ),
            IconButton(
              onPressed: () =>
                  _showRefillDialog(context, fileProvider, dateString),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refill undone todos until today',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Calendar events, tasks, and notes sections
        if (dailyFile != null)
          GestureDetector(
            onDoubleTap: () => _openDailyEditor(
                context, fileProvider, dateString, initialContent),
            child: Column(
              children: [
                _buildCalendarEventsSection(fileProvider, dateString),
                const SizedBox(height: 12),
                _buildTasksSection(fileProvider, dateString),
                const SizedBox(height: 12),
                _buildNotesSection(fileProvider, dateString),
              ],
            ),
          ),
      ],
    );
  }

  void _loadDailyContent(DateTime day) {
    final dateString = _formatDate(day);
    context.read<FileProvider>().setSelectedDate(dateString);
  }

  void _showQuickAddModal(BuildContext context, FileProvider fileProvider) {
    if (_selectedDay == null) return;
    
    final dateString = _formatDate(_selectedDay!);
    final dailyFile = fileProvider.getDailyFile(dateString);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentContent = dailyFile?.content ?? themeProvider.dailyTemplate;
    
    showDialog(
      context: context,
      builder: (context) => QuickAddModal(
        selectedDate: _selectedDay!,
        onAdd: (content) {
          // Append the new content to the existing daily content
          final newContent = currentContent.isEmpty 
              ? content 
              : '$currentContent\n\n$content';
          fileProvider.saveDailyFile(dateString, newContent);
        },
      ),
    );
  }

  void _openDailyEditor(BuildContext context, FileProvider fileProvider,
      String dateString, String initialContent) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DailyEditorFullscreen(
          date: dateString,
          initialContent: initialContent,
          onSave: (content) {
            fileProvider.saveDailyFile(dateString, content);
          },
          onAutoSave: (content) {
            fileProvider.saveDailyFile(dateString, content);
            // Don't show snackbar for autosave
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCustomDay(BuildContext context, DateTime day,
      DateTime focusedDay, FileProvider fileProvider,
      {bool isSelected = false, bool isToday = false}) {
    final dateString = _formatDate(day);
    final undoneTodoCount = fileProvider.getUndoneTodoCount(dateString);
    final hasTodos = fileProvider.hasTodos(dateString);
    final hasDailyFile = fileProvider.getDailyFile(dateString) != null;
    final hasCalendarEvents = fileProvider.hasCalendarEvents(dateString);
    final isOutsideMonth = day.month != focusedDay.month;

    return CalendarDayWidget(
      day: day,
      isSelected: isSelected,
      isToday: isToday,
      isOutsideMonth: isOutsideMonth,
      undoneTodoCount: undoneTodoCount,
      hasTodos: hasTodos,
      hasDailyFile: hasDailyFile,
      hasCalendarEvents: hasCalendarEvents,
    );
  }

  Widget _buildCalendarEventsSection(
      FileProvider fileProvider, String dateString) {
    final events = fileProvider.getCalendarEvents(dateString);

    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Events',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...events
              .map((event) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    event.formattedTime,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      event.displayTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              if (event.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  event.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildTasksSection(FileProvider fileProvider, String dateString) {
    final dailyFile = fileProvider.getDailyFile(dateString);
    if (dailyFile == null || dailyFile.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final tasks = _parseTasks(dailyFile.content);

    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.task_alt,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tasks
              .map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: task.isCompleted
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            task.text,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isCompleted
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                      : null,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  List<TaskItem> _parseTasks(String content) {
    final tasks = <TaskItem>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final todoMatch =
          RegExp(r'^\s*[-*+]\s*\[\s*([x\s])\s*\]\s+(.+)$').firstMatch(line);
      if (todoMatch != null) {
        final isCompleted = todoMatch.group(1) == 'x';
        final text = todoMatch.group(2)!.trim();
        tasks.add(TaskItem(
          text: text,
          isCompleted: isCompleted,
        ));
      }
    }

    return tasks;
  }

  Widget _buildNotesSection(FileProvider fileProvider, String dateString) {
    final dailyFile = fileProvider.getDailyFile(dateString);
    if (dailyFile == null || dailyFile.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final notes = _parseNotes(dailyFile.content);

    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notes,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...notes
              .map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            note,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  List<String> _parseNotes(String content) {
    final notes = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Skip empty lines
      if (trimmedLine.isEmpty) continue;

      // Skip events (lines with @HH:MM)
      if (RegExp(r'@\d{1,2}:\d{2}').hasMatch(trimmedLine)) continue;

      // Skip tasks (lines with [ ] or [x])
      if (RegExp(r'^\s*[-*+]\s*\[\s*[x\s]\s*\]\s+').hasMatch(trimmedLine))
        continue;

      // Skip markdown headers (lines starting with #)
      if (trimmedLine.startsWith('#')) continue;

      // Skip markdown list markers without checkboxes
      if (RegExp(r'^\s*[-*+]\s+').hasMatch(trimmedLine)) {
        final cleanLine =
            trimmedLine.replaceAll(RegExp(r'^\s*[-*+]\s+'), '').trim();
        if (cleanLine.isNotEmpty) {
          notes.add(cleanLine);
        }
        continue;
      }

      // Add regular text content
      notes.add(trimmedLine);
    }

    return notes;
  }

  void _showRefileDialog(
      BuildContext context, FileProvider fileProvider, String currentDate) {
    final dailyFile = fileProvider.getDailyFile(currentDate);
    if (dailyFile == null || dailyFile.content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No content to refile')),
      );
      return;
    }

    final events = fileProvider.getCalendarEvents(currentDate);
    final tasks = _parseTasks(dailyFile.content);
    final notes = _parseNotes(dailyFile.content);

    if (events.isEmpty && tasks.isEmpty && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to refile')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _RefileDialog(
        currentDate: currentDate,
        events: events,
        tasks: tasks,
        notes: notes,
        onRefile: (targetDate, items) {
          _performRefile(context, fileProvider, currentDate, targetDate, items);
        },
      ),
    );
  }

  void _performRefile(BuildContext context, FileProvider fileProvider,
      String currentDate, String targetDate, List<RefileItem> items) {
    final dailyFile = fileProvider.getDailyFile(currentDate);
    if (dailyFile == null) return;

    // Get target daily file
    final targetDailyFile = fileProvider.getDailyFile(targetDate);
    final targetContent = targetDailyFile?.content ?? '';

    // Remove items from current file
    String newCurrentContent = dailyFile.content;
    for (final item in items) {
      newCurrentContent = _removeItemFromContent(newCurrentContent, item);
    }

    // Add items to target file
    String newTargetContent = targetContent;
    if (newTargetContent.isNotEmpty && !newTargetContent.endsWith('\n')) {
      newTargetContent += '\n';
    }

    for (final item in items) {
      newTargetContent += item.content + '\n';
    }

    // Save both files
    fileProvider.saveDailyFile(currentDate, newCurrentContent);
    fileProvider.saveDailyFile(targetDate, newTargetContent);

    // Refresh the UI
    setState(() {});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Moved ${items.length} item(s) to ${_formatDisplayDate(_parseDateFromString(targetDate))}')),
      );
    }
  }

  String _removeItemFromContent(String content, RefileItem item) {
    final lines = content.split('\n');
    final newLines = <String>[];

    for (final line in lines) {
      if (line.trim() != item.content.trim()) {
        newLines.add(line);
      }
    }

    return newLines.join('\n');
  }

  DateTime _parseDateFromString(String dateString) {
    final year = int.parse(dateString.substring(0, 4));
    final month = int.parse(dateString.substring(4, 6));
    final day = int.parse(dateString.substring(6, 8));
    return DateTime(year, month, day);
  }

  void _showRefillDialog(
      BuildContext context, FileProvider fileProvider, String currentDate) {
    final today = DateTime.now();
    final currentDateTime = _parseDateFromString(currentDate);

    // Only show refill if current date is today
    if (!isSameDay(currentDateTime, today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refill is only available for today')),
      );
      return;
    }

    // Collect all undone todos from previous days
    final undoneTodos = <RefillTodo>[];
    final todayDateString = _formatDate(today);

    // Check the last 30 days for undone todos
    for (int i = 1; i <= 30; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final checkDateString = _formatDate(checkDate);
      final dailyFile = fileProvider.getDailyFile(checkDateString);

      if (dailyFile != null && dailyFile.content.isNotEmpty) {
        final tasks = _parseTasks(dailyFile.content);
        for (final task in tasks) {
          if (!task.isCompleted) {
            undoneTodos.add(RefillTodo(
              content: '- [ ] ${task.text}',
              sourceDate: checkDateString,
              sourceDateDisplay: _formatDisplayDate(checkDate),
            ));
          }
        }
      }
    }

    if (undoneTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No undone todos found in the last 30 days')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _RefillDialog(
        undoneTodos: undoneTodos,
        onRefill: (selectedTodos) {
          _performRefill(context, fileProvider, selectedTodos);
        },
      ),
    );
  }

  void _performRefill(BuildContext context, FileProvider fileProvider,
      List<RefillTodo> selectedTodos) {
    final today = DateTime.now();
    final todayDateString = _formatDate(today);

    // Get today's content
    final todayDailyFile = fileProvider.getDailyFile(todayDateString);
    String todayContent = todayDailyFile?.content ?? '';

    // Add todos to today
    if (todayContent.isNotEmpty && !todayContent.endsWith('\n')) {
      todayContent += '\n';
    }

    // Group todos by source date for removal
    final todosByDate = <String, List<RefillTodo>>{};
    for (final todo in selectedTodos) {
      todosByDate.putIfAbsent(todo.sourceDate, () => []).add(todo);
    }

    // Remove todos from source dates
    for (final entry in todosByDate.entries) {
      final sourceDate = entry.key;
      final todos = entry.value;
      final sourceDailyFile = fileProvider.getDailyFile(sourceDate);

      if (sourceDailyFile != null) {
        String newSourceContent = sourceDailyFile.content;
        for (final todo in todos) {
          newSourceContent = _removeItemFromContent(
              newSourceContent,
              RefileItem(
                content: todo.content,
                type: 'task',
              ));
        }
        fileProvider.saveDailyFile(sourceDate, newSourceContent);
      }
    }

    // Add todos to today
    for (final todo in selectedTodos) {
      todayContent += todo.content + '\n';
    }

    fileProvider.saveDailyFile(todayDateString, todayContent);

    // Refresh the UI
    setState(() {});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Refilled ${selectedTodos.length} undone todo(s) to today')),
      );
    }
  }
}

class TaskItem {
  final String text;
  final bool isCompleted;

  TaskItem({
    required this.text,
    required this.isCompleted,
  });
}

class RefileItem {
  final String content;
  final String type; // 'event', 'task', 'note'

  RefileItem({
    required this.content,
    required this.type,
  });
}

class RefillTodo {
  final String content;
  final String sourceDate;
  final String sourceDateDisplay;

  RefillTodo({
    required this.content,
    required this.sourceDate,
    required this.sourceDateDisplay,
  });
}

class _RefileDialog extends StatefulWidget {
  final String currentDate;
  final List<CalendarEvent> events;
  final List<TaskItem> tasks;
  final List<String> notes;
  final Function(String, List<RefileItem>) onRefile;

  const _RefileDialog({
    required this.currentDate,
    required this.events,
    required this.tasks,
    required this.notes,
    required this.onRefile,
  });

  @override
  State<_RefileDialog> createState() => _RefileDialogState();
}

class _RefileDialogState extends State<_RefileDialog> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, bool> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = _parseDateFromString(widget.currentDate);
  }

  DateTime _parseDateFromString(String dateString) {
    final year = int.parse(dateString.substring(0, 4));
    final month = int.parse(dateString.substring(4, 6));
    final day = int.parse(dateString.substring(6, 8));
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refile Items'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date picker
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Target Date'),
              subtitle: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
            ),
            const Divider(),

            // Items to refile
            const Text('Select items to move:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Events
            if (widget.events.isNotEmpty) ...[
              const Text('Events:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              ...widget.events.map((CalendarEvent event) {
                final eventKey = '${event.formattedTime} ${event.displayTitle}';
                return CheckboxListTile(
                  title: Text(eventKey),
                  value: _selectedItems[eventKey] ?? false,
                  onChanged: (value) {
                    setState(() {
                      _selectedItems[eventKey] = value ?? false;
                    });
                  },
                  dense: true,
                );
              }),
            ],

            // Tasks
            if (widget.tasks.isNotEmpty) ...[
              const Text('Tasks:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              ...widget.tasks.map((task) => CheckboxListTile(
                    title: Text(
                        '${task.isCompleted ? "[x]" : "[ ]"} ${task.text}'),
                    value: _selectedItems[task.text] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _selectedItems[task.text] = value ?? false;
                      });
                    },
                    dense: true,
                  )),
            ],

            // Notes
            if (widget.notes.isNotEmpty) ...[
              const Text('Notes:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              ...widget.notes.map((note) => CheckboxListTile(
                    title: Text(note),
                    value: _selectedItems[note] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _selectedItems[note] = value ?? false;
                      });
                    },
                    dense: true,
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final selectedItems = <RefileItem>[];

            // Collect selected events
            for (final event in widget.events) {
              final eventKey = '${event.formattedTime} ${event.displayTitle}';
              if (_selectedItems[eventKey] == true) {
                // Use the original title which includes @HH:MM
                final eventContent = event.title;
                if (event.description.isNotEmpty) {
                  selectedItems.add(RefileItem(
                      content: '$eventContent\n${event.description}',
                      type: 'event'));
                } else {
                  selectedItems
                      .add(RefileItem(content: eventContent, type: 'event'));
                }
              }
            }

            // Collect selected tasks
            for (final task in widget.tasks) {
              if (_selectedItems[task.text] == true) {
                selectedItems.add(RefileItem(
                    content: '- [${task.isCompleted ? "x" : " "}] ${task.text}',
                    type: 'task'));
              }
            }

            // Collect selected notes
            for (final note in widget.notes) {
              if (_selectedItems[note] == true) {
                selectedItems.add(RefileItem(content: note, type: 'note'));
              }
            }

            if (selectedItems.isNotEmpty) {
              widget.onRefile(_formatDate(_selectedDate), selectedItems);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Move'),
        ),
      ],
    );
  }
}

class _RefillDialog extends StatefulWidget {
  final List<RefillTodo> undoneTodos;
  final Function(List<RefillTodo>) onRefill;

  const _RefillDialog({
    required this.undoneTodos,
    required this.onRefill,
  });

  @override
  State<_RefillDialog> createState() => _RefillDialogState();
}

class _RefillDialogState extends State<_RefillDialog> {
  final Map<String, bool> _selectedTodos = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refill Undone Todos'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found ${widget.undoneTodos.length} undone todos from the last 30 days:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Select all/none buttons
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final todo in widget.undoneTodos) {
                        _selectedTodos[todo.content] = true;
                      }
                    });
                  },
                  child: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTodos.clear();
                    });
                  },
                  child: const Text('Select None'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Todos list
            Expanded(
              child: ListView.builder(
                itemCount: widget.undoneTodos.length,
                itemBuilder: (context, index) {
                  final todo = widget.undoneTodos[index];
                  return CheckboxListTile(
                    title: Text(todo.content),
                    subtitle: Text('From ${todo.sourceDateDisplay}'),
                    value: _selectedTodos[todo.content] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _selectedTodos[todo.content] = value ?? false;
                      });
                    },
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final selectedTodos = widget.undoneTodos
                .where((todo) => _selectedTodos[todo.content] == true)
                .toList();

            if (selectedTodos.isNotEmpty) {
              widget.onRefill(selectedTodos);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Refill to Today'),
        ),
      ],
    );
  }
}

