import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../calendar_provider.dart';
import '../event_bookmarks_provider.dart';
import '../utils/calendar_event_utils.dart';
import 'cofradeo_calendar.dart';

class CalendarMonthSheet extends ConsumerStatefulWidget {
  const CalendarMonthSheet({
    super.key,
    required this.focusedMonth,
    required this.events,
    required this.filter,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDayTap,
  });

  final DateTime focusedMonth;
  final List<CalendarEvent> events;
  final EventFilter filter;
  final int? selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final void Function(int day, List<CalendarEvent> dayEvents) onDayTap;

  static Future<void> show(
    BuildContext context, {
    required DateTime focusedMonth,
    required List<CalendarEvent> events,
    required EventFilter filter,
    required int? selectedDay,
    required ValueChanged<DateTime> onMonthChanged,
    required void Function(int day, List<CalendarEvent> dayEvents) onDayTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CalendarMonthSheet(
        focusedMonth: focusedMonth,
        events: events,
        filter: filter,
        selectedDay: selectedDay,
        onMonthChanged: onMonthChanged,
        onDayTap: onDayTap,
      ),
    );
  }

  @override
  ConsumerState<CalendarMonthSheet> createState() => _CalendarMonthSheetState();
}

class _CalendarMonthSheetState extends ConsumerState<CalendarMonthSheet> {
  late DateTime _focusedMonth;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.focusedMonth;
    _selectedDay = widget.selectedDay;
  }

  void _handleMonthChanged(DateTime month) {
    setState(() {
      _focusedMonth = month;
      if (_selectedDay != null) {
        final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
        if (_selectedDay! > daysInMonth) {
          _selectedDay = daysInMonth;
        }
      }
    });
    widget.onMonthChanged(month);
  }

  void _goToToday() {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final events =
        ref.read(calendarEventsProvider(month)).value ?? widget.events;
    setState(() {
      _focusedMonth = month;
      _selectedDay = now.day;
    });
    widget.onMonthChanged(month);
    widget.onDayTap(
      now.day,
      eventsOnDay(events, month, now.day).where(widget.filter.matches).toList(),
    );
    Navigator.pop(context);
  }

  void _handleDayTap(int day, List<CalendarEvent> dayEvents) {
    setState(() => _selectedDay = day);
    widget.onDayTap(day, dayEvents);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider(_focusedMonth));
    final events = eventsAsync.maybeWhen(
      data: (data) => data,
      orElse: () => widget.events,
    );
    final isLoading = eventsAsync.isLoading && eventsAsync.value == null;
    final bookmarkIds = ref.watch(eventBookmarkIdsProvider).value ?? {};
    final monthEventCount = events
        .where(
          (event) =>
              event.date.year == _focusedMonth.year &&
              event.date.month == _focusedMonth.month &&
              eventMatchesCalendarFilter(event, widget.filter, bookmarkIds),
        )
        .length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? 4 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendario mensual',
                        style: AppTypography.displaySmall().copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthEventCount == 0
                            ? 'Sin eventos este mes'
                            : '$monthEventCount evento${monthEventCount == 1 ? '' : 's'} en el mes',
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Hoy',
                    style: AppTypography.bodyMedium(
                      color: AppColors.burgundy,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 22),
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.85),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CofradeoCalendar(
                    focusedMonth: _focusedMonth,
                    events: events,
                    filter: widget.filter,
                    selectedDay: _selectedDay,
                    onMonthChanged: _handleMonthChanged,
                    onDayTap: _handleDayTap,
                  ),
                ),
                if (isLoading)
                  const Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Toca un día para ver sus eventos',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: AppColors.textMuted)
                  .copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
