import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum QuickAddType {
  event,
  todo,
}

class QuickAddModal extends StatefulWidget {
  final DateTime selectedDate;
  final Function(String content) onAdd;

  const QuickAddModal({
    super.key,
    required this.selectedDate,
    required this.onAdd,
  });

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal> {
  QuickAddType _selectedType = QuickAddType.event;
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    // Set default time to next hour on the selected date
    final now = DateTime.now();
    _selectedDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      now.hour + 1,
      0, // Start of the hour
    );
    _selectedTime = TimeOfDay.fromDateTime(_selectedDateTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatTime24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.add_circle_outline, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Add',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Adding to ${DateFormat('MMM dd, yyyy').format(widget.selectedDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Type selection
            RadioGroup<QuickAddType>(
              groupValue: _selectedType,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedType = value;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Event'),
                      subtitle: const Text('With time'),
                      leading: const Radio<QuickAddType>(
                        value: QuickAddType.event,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedType = QuickAddType.event;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Todo'),
                      subtitle: const Text('Task'),
                      leading: const Radio<QuickAddType>(
                        value: QuickAddType.todo,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedType = QuickAddType.todo;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Enter title...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // Time selection (only for events)
            if (_selectedType == QuickAddType.event) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_formatTime24Hour(_selectedTime)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Add button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: Text(_selectedType == QuickAddType.event
                    ? 'Add Event'
                    : 'Add Todo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDateTime = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _addItem() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    String content;
    if (_selectedType == QuickAddType.event) {
      final timeStr = _formatTime24Hour(_selectedTime);
      content = '- @$timeStr $title';
    } else {
      content = '- [ ] $title';
    }

    widget.onAdd(content);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _selectedType == QuickAddType.event ? 'Event added' : 'Todo added'),
      ),
    );
  }
}
