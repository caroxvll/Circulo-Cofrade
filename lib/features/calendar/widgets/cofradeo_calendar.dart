import 'package:flutter/material.dart';

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
  static const _cellSize = 36.0;
  static const _dotRowHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    final monthLabel = formatCalendarMonthLabel(focusedMonth);
    final yearLabel = '${focusedMonth.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _MonthArrow(
              icon: Icons.chevron_left,
              onTap: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month - 1),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    monthLabel,
                    style: AppTypography.displaySmall().copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    yearLabel,
                    style: AppTypography.bodyMedium(
                      color: AppColors.textMuted,
                    ).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _MonthArrow(
              icon: Icons.chevron_right,
              onTap: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month + 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: _weekdays
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.labelSmall(
                        color: AppColors.textSecondary,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
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
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final startOffset = firstDay.weekday - 1;

    final cells = <Widget>[];
    final now = DateTime.now();
    final isFocusedCurrentMonth =
        focusedMonth.year == now.year && focusedMonth.month == now.month;
    for (var day = 1; day <= daysInMonth; day++) {
      final dayEvents = eventsOnDay(
        events,
        focusedMonth,
        day,
      ).where(filter.matches).toList();
      cells.add(
        _DayCell(
          day: day,
          events: dayEvents,
          isToday: isFocusedCurrentMonth && day == now.day,
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
        child: SizedBox(
          width: 36,
          height: 36,
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
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final List<CalendarEvent> events;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEvent = events.isNotEmpty;
    final dayColor = isSelected
        ? AppColors.textOnDark
        : isToday
            ? AppColors.burgundy
            : AppColors.textPrimary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: CofradeoCalendar._cellSize + CofradeoCalendar._dotRowHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: CofradeoCalendar._cellSize,
                  height: CofradeoCalendar._cellSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected
                        ? AppColors.burgundy
                        : isToday
                            ? AppColors.gold.withValues(alpha: 0.14)
                            : Colors.transparent,
                    border: !isSelected && (isToday || hasEvent)
                        ? Border.all(
                            color: isToday
                                ? AppColors.burgundy
                                : AppColors.gold.withValues(alpha: 0.75),
                            width: isToday ? 1.4 : 1,
                          )
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: AppTypography.bodyMedium(color: dayColor).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  height: CofradeoCalendar._dotRowHeight,
                  child: hasEvent
                      ? _EventDots(
                          events: events,
                          isSelected: isSelected,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDots extends StatelessWidget {
  const _EventDots({required this.events, required this.isSelected});

  final List<CalendarEvent> events;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final visible = events.length.clamp(1, 3);
    final extra = events.length - visible;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < visible; index++)
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.textOnDark.withValues(alpha: 0.9)
                  : _dotColor(events[index].type),
            ),
          ),
        if (extra > 0)
          Text(
            '+$extra',
            style: AppTypography.labelSmall(
              color: isSelected ? AppColors.textOnDark : AppColors.textMuted,
            ).copyWith(fontSize: 7.5, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}

Color _dotColor(EventType type) {
  return switch (type) {
    EventType.iguala => AppColors.burgundy,
    EventType.ensayo => AppColors.burgundy,
    EventType.procesion => AppColors.burgundy,
    _ => AppColors.goldDark,
  };
}
