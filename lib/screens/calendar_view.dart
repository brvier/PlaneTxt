import 'package:flutter/material.dart';
import 'package:planova/models/daily_file.dart';
import 'package:planova/providers/daily_file_provider.dart';

import 'package:planova/providers/theme_provider.dart';
import 'package:planova/utils/daily_content_helper.dart';
import 'package:planova/utils/markdown_parser.dart';
import 'package:planova/widgets/calendar_day_widget.dart';
import 'package:planova/widgets/daily_editor_fullscreen.dart';
import 'package:planova/widgets/quick_add_modal.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

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
    return Consumer<DailyFileProvider>(
      builder: (context, dailyFileProvider, child) {
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
                  cellPadding: EdgeInsets.zero, // Remove internal cell padding
                  cellMargin: EdgeInsets.zero, // Remove internal cell margin
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildCustomDay(
                        context, day, focusedDay, dailyFileProvider);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildCustomDay(
                        context, day, focusedDay, dailyFileProvider,
                        isSelected: true);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildCustomDay(
                        context, day, focusedDay, dailyFileProvider,
                        isToday: true);
                  },
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronPadding: EdgeInsets.zero, // Remove header padding
                  rightChevronPadding: EdgeInsets.zero, // Remove header padding
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
                        child: _buildDailyContent(dailyFileProvider),
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

  Widget _buildDailyContent(DailyFileProvider dailyFileProvider) {
    final dateString = _formatDate(_selectedDay!);
    final dailyFile = dailyFileProvider.getDailyFileFromCache(dateString);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final initialContent = dailyFile?.content ?? themeProvider.dailyTemplate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () => _showQuickAddModal(context, dailyFileProvider),
              icon: const Icon(Icons.add),
              tooltip: 'Quick add event or todo',
            ),
            IconButton(
              onPressed: () => _openDailyEditor(
                  context, dailyFileProvider, dateString, initialContent),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit daily notes',
            ),
            IconButton(
              onPressed: () =>
                  _showRefillDialog(context, dailyFileProvider, dateString),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refill undone todos to this day',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Calendar events, tasks, and notes sections
        if (dailyFile != null)
          GestureDetector(
            onDoubleTap: () => _openDailyEditor(
                context, dailyFileProvider, dateString, initialContent),
            child: Column(
              children: [
                _buildCalendarEventsSection(dailyFileProvider, dateString),
                const SizedBox(height: 12),
                _buildTasksSection(dailyFileProvider, dateString),
                const SizedBox(height: 12),
                _buildNotesSection(dailyFileProvider, dateString),
              ],
            ),
          ),
      ],
    );
  }

  void _loadDailyContent(DateTime day) {
    final dateString = _formatDate(day);
    context.read<DailyFileProvider>().setSelectedDate(dateString);
  }

  void _showQuickAddModal(
      BuildContext context, DailyFileProvider dailyFileProvider) async {
    if (_selectedDay == null) return;

    final dateString = _formatDate(_selectedDay!);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Ensure daily file is loaded (check disk if not in memory)
    final dailyFile = await dailyFileProvider.ensureDailyFileLoaded(dateString);

    final currentContent = dailyFile?.content ?? themeProvider.dailyTemplate;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => QuickAddModal(
        selectedDate: _selectedDay!,
        onAdd: (content) {
          // Determine if it's a todo or event based on content format
          // Events: "- @HH:MM title"
          // Todos: "- [ ] title"
          final isEvent = content.startsWith('- @');

          // Insert content after the last item in the section
          String newContent;
          if (isEvent) {
            newContent = DailyContentHelper.insertAfterLastEvent(
              currentContent,
              content,
              themeProvider.eventHeaderRegex,
            );
          } else {
            newContent = DailyContentHelper.insertAfterLastTodo(
              currentContent,
              content,
              themeProvider.todoHeaderRegex,
            );
          }

          dailyFileProvider.saveDailyFile(context, dateString, newContent);
        },
      ),
    );
  }

  void _openDailyEditor(
      BuildContext context,
      DailyFileProvider dailyFileProvider,
      String dateString,
      String initialContent) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DailyEditorFullscreen(
          date: dateString,
          initialContent: initialContent,
          onSave: (content) {
            dailyFileProvider.saveDailyFile(context, dateString, content);
          },
          onAutoSave: (content) {
            dailyFileProvider.saveDailyFile(context, dateString, content);
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
      DateTime focusedDay, DailyFileProvider dailyFileProvider,
      {bool isSelected = false, bool isToday = false}) {
    final dateString = _formatDate(day);
    final dailyFile = dailyFileProvider.getDailyFileFromCache(dateString);
    final hasDailyFile = dailyFile != null;
    final hasContent = hasDailyFile && dailyFile.content.isNotEmpty;
    final tasks = hasContent ? MarkdownParser.parseTasks(dailyFile.content) : <TaskItem>[];
    final undoneTodoCount = tasks.where((task) => !task.isCompleted).length;
    final hasTodos = tasks.isNotEmpty;
    final hasCalendarEvents = hasContent
        ? MarkdownParser.parseEvents(dateString, dailyFile.content).isNotEmpty
        : false;
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
      DailyFileProvider dailyFileProvider, String dateString) {
    final events = dailyFileProvider.getCalendarEvents(dateString);

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
          ...events.map((event) => Padding(
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
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event.displayTitle,
                                  style: Theme.of(context).textTheme.bodyMedium,
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
              )),
        ],
      ),
    );
  }

  Widget _buildTasksSection(
      DailyFileProvider dailyFileProvider, String dateString) {
    final dailyFile = dailyFileProvider.getDailyFileFromCache(dateString);
    if (dailyFile == null || dailyFile.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final tasks = MarkdownParser.parseTasks(dailyFile.content);

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
          ...tasks.map((task) => Padding(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              )),
        ],
      ),
    );
  }

  Widget _buildNotesSection(
      DailyFileProvider dailyFileProvider, String dateString) {
    final dailyFile = dailyFileProvider.getDailyFileFromCache(dateString);
    if (dailyFile == null || dailyFile.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final notes = MarkdownParser.parseNotes(dailyFile.content);

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
          ...notes.map((note) => Padding(
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
              )),
        ],
      ),
    );
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

  void _showRefillDialog(BuildContext context,
      DailyFileProvider dailyFileProvider, String currentDate) {
    final currentDateTime = _parseDateFromString(currentDate);

    // Collect all undone todos from previous days up to the selected date
    final undoneTodos = <RefillTodo>[];

    // Check the last 30 days for undone todos, but only up to the selected date
    for (int i = 1; i <= 30; i++) {
      final checkDate = currentDateTime.subtract(Duration(days: i));
      final checkDateString = _formatDate(checkDate);
      final dailyFile =
          dailyFileProvider.getDailyFileFromCache(checkDateString);

      if (dailyFile != null && dailyFile.content.isNotEmpty) {
        final tasks = MarkdownParser.parseTasks(dailyFile.content);
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
          _performRefill(
              context, dailyFileProvider, selectedTodos, currentDate);
        },
      ),
    );
  }

  void _performRefill(BuildContext context, DailyFileProvider dailyFileProvider,
      List<RefillTodo> selectedTodos, String targetDate) async {
    final targetDateString = targetDate;

    // Ensure target date file is loaded (check disk if not in memory)
    final targetDailyFile =
        await dailyFileProvider.ensureDailyFileLoaded(targetDateString);
    String targetContent = targetDailyFile?.content ?? '';

    // Add todos to target date
    if (targetContent.isNotEmpty && !targetContent.endsWith('\n')) {
      targetContent += '\n';
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
      final sourceDailyFile = await dailyFileProvider.getDailyFile(sourceDate);

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
        if (context.mounted) {
          dailyFileProvider.saveDailyFile(
              context, sourceDate, newSourceContent);
        }
      }
    }

    // Add todos to target date
    for (final todo in selectedTodos) {
      targetContent += '${todo.content}\n';
    }

    if (context.mounted) {
      dailyFileProvider.saveDailyFile(context, targetDateString, targetContent);

      // Refresh the UI
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Refilled ${selectedTodos.length} undone todo(s) to ${_formatDisplayDate(_parseDateFromString(targetDateString))}')),
      );
    }
  }
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
      title: const Text('Refill Undone Todos to Selected Day'),
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
          child: const Text('Refill to Selected Day'),
        ),
      ],
    );
  }
}
