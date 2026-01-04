import 'package:flutter/material.dart';

class CalendarDayWidget extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final bool isOutsideMonth;
  final int undoneTodoCount;
  final bool hasTodos;
  final bool hasDailyFile;
  final bool hasCalendarEvents;

  const CalendarDayWidget({
    super.key,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isOutsideMonth,
    required this.undoneTodoCount,
    required this.hasTodos,
    required this.hasDailyFile,
    required this.hasCalendarEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // Day number
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: isOutsideMonth
                    ? Theme.of(context).colorScheme.outline
                    : isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : isToday
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          // Indicators
          if ((hasTodos || hasDailyFile || hasCalendarEvents) &&
              !isOutsideMonth)
            Positioned(
              bottom: 2,
              left: 0,
              right: 0,
              child: Center(
                child: _buildIndicator(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIndicator(BuildContext context) {
    if (hasTodos) {
      if (undoneTodoCount == 0) {
        // All todos done - green checkmark
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 8,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
        );
      } else if (undoneTodoCount <= 3) {
        // Show dots for undone todos (max 3)
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            undoneTodoCount.clamp(0, 3),
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      } else {
        // More than 3 undone todos - show number
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$undoneTodoCount',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } else if (hasCalendarEvents) {
      // Has calendar events - blue dot
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      );
    } else if (hasDailyFile) {
      // Has daily file but no todos or events - green dot
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
