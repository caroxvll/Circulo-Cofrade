import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../utils/calendar_event_utils.dart';

class CofradeoCalendar extends StatelessWidget {
  const CofradeoCalendar({
    super.key,
    required this.focusedMonth,
    required this.events,
    required this.onMonthChanged,
    required this.onDayTap,
    this.filter = EventFilter.todas,
    this.selectedDay,
  });

  final DateTime focusedMonth;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onMonthChanged;
  final void Function(int day, List<CalendarEvent> events) onDayTap;
  final EventFilter filter;
  final int? selectedDay;

  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'es').format(focusedMonth);
    final capitalizedMonth =
        '${monthName[0].toUpperCase()}${monthName.substring(1)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MonthArrow(
              icon: Icons.chevron_left,
              onTap: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month - 1),
              ),
            ),
            Text(
              capitalizedMonth,
              style: AppTypography.displaySmall(color: AppColors.textPrimary),
            ),
            _MonthArrow(
              icon: Icons.chevron_right,
              onTap: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month + 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: _weekdays
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.labelSmall(
                        color: AppColors.textMuted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ..._buildWeeks(),
      ],
    );
  }

  List<Widget> _buildWeeks() {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;

    final cells = <Widget>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final dayEvents =
          eventsOnDay(events, focusedMonth, day).where(filter.matches).toList();
      cells.add(
        _DayCell(
          day: day,
          events: dayEvents,
          isSelected: selectedDay == day,
          onTap: () => onDayTap(day, dayEvents),
        ),
      );
    }

    final leadingBlanks = List.generate(
      startOffset,
      (_) => const Expanded(child: SizedBox()),
    );

    final rows = <Widget>[];
    var index = 0;
    final allCells = [...leadingBlanks, ...cells];

    while (index < allCells.length) {
      final end = (index + 7).clamp(0, allCells.length);
      final week = allCells.sublist(index, end);
      while (week.length < 7) {
        week.add(const Expanded(child: SizedBox()));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: week,
          ),
        ),
      );
      index += 7;
    }

    return rows;
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.burgundy, size: 22),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.events,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final List<CalendarEvent> events;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEvent = events.isNotEmpty;
    final cellLabel = _dayCellLabel(events);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.burgundy
                        : hasEvent
                            ? AppColors.gold.withValues(alpha: 0.12)
                            : null,
                    border: hasEvent || isSelected
                        ? Border.all(
                            color: isSelected
                                ? AppColors.burgundy
                                : AppColors.gold,
                            width: isSelected ? 2 : 2,
                          )
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: AppTypography.bodyMedium(
                      color: isSelected
                          ? AppColors.textOnDark
                          : hasEvent
                              ? AppColors.goldDark
                              : AppColors.textPrimary,
                    ).copyWith(
                      fontWeight:
                          hasEvent || isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (hasEvent && cellLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    cellLabel,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall(
                      color: isSelected ? AppColors.burgundy : AppColors.burgundy,
                    ).copyWith(fontSize: 8, height: 1.1, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _dayCellLabel(List<CalendarEvent> events) {
  if (events.isEmpty) return null;
  if (events.length == 1) return events.first.calendarCellLabel;
  final labels = events.map((e) => e.calendarCellLabel).toSet().toList();
  if (labels.length == 1) return '${labels.first}\n×${events.length}';
  return '${events.length}\neventos';
}
