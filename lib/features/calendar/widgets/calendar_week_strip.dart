import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../calendar_design_tokens.dart';
import '../event_bookmarks_provider.dart';
import '../utils/calendar_event_utils.dart';

class CalendarWeekStrip extends StatelessWidget {
  const CalendarWeekStrip({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.filter,
    required this.bookmarkIds,
    required this.onDaySelected,
    required this.onOpenMonthCalendar,
  });

  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final EventFilter filter;
  final Set<String> bookmarkIds;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onOpenMonthCalendar;

  static const _weekdayLabels = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final days = weekDaysContaining(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _WeekDayChip(
              day: days[i].day,
              weekday: _weekdayLabels[days[i].weekday - 1],
              isSelected: isSameCalendarDay(days[i], selectedDate),
              isToday: isSameCalendarDay(days[i], today),
              hasEvents: eventsOnDate(events, days[i])
                  .where(
                    (event) => eventMatchesCalendarFilter(
                      event,
                      filter,
                      bookmarkIds,
                    ),
                  )
                  .isNotEmpty,
              onTap: () => onDaySelected(days[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.day,
    required this.weekday,
    required this.isSelected,
    required this.isToday,
    required this.hasEvents,
    required this.onTap,
  });

  final int day;
  final String weekday;
  final bool isSelected;
  final bool isToday;
  final bool hasEvents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppColors.burgundy
        : isToday
            ? AppColors.surface
            : AppColors.surfaceAlt;
    final dayColor = isSelected ? AppColors.textOnDark : AppColors.textPrimary;
    final weekdayColor =
        isSelected ? AppColors.textOnDark.withValues(alpha: 0.9) : AppColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CalendarDesign.weekTileRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CalendarDesign.weekTileRadius),
          child: Container(
            height: CalendarDesign.weekStripTileHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(CalendarDesign.weekTileRadius),
              border: Border.all(
                color: isSelected
                    ? AppColors.burgundy
                    : isToday
                        ? AppColors.burgundy.withValues(alpha: 0.45)
                        : AppColors.border.withValues(alpha: 0.65),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: AppTypography.titleLarge(color: dayColor).copyWith(
                    fontSize: CalendarDesign.weekDayFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  weekday,
                  style: AppTypography.labelSmall(color: weekdayColor).copyWith(
                    fontSize: CalendarDesign.weekLabelFontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    height: 1,
                  ),
                  maxLines: 1,
                ),
                if (isSelected || hasEvents)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.textOnDark : AppColors.goldDark,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
