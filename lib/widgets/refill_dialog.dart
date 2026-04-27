import 'package:flutter/material.dart';

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

class RefileItem {
  final String content;
  final String type;

  RefileItem({required this.content, required this.type});
}

class RefillDialog extends StatefulWidget {
  final List<RefillTodo> undoneTodos;
  final Function(List<RefillTodo>) onRefill;

  const RefillDialog({
    super.key,
    required this.undoneTodos,
    required this.onRefill,
  });

  @override
  State<RefillDialog> createState() => _RefillDialogState();
}

class _RefillDialogState extends State<RefillDialog> {
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
