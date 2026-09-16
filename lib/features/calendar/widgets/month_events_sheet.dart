import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../utils/calendar_event_utils.dart';
import 'event_card.dart';

/// Hoja inferior con todos los eventos del mes (lista acotada, no eterna en pantalla).
class MonthEventsSheet extends StatelessWidget {
  const MonthEventsSheet({
    super.key,
    required this.month,
    required this.events,
    required this.onEventTap,
  });

  final DateTime month;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  static Future<void> show(
    BuildContext context, {
    required DateTime month,
    required List<CalendarEvent> events,
    required ValueChanged<CalendarEvent> onEventTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => MonthEventsSheet(
        month: month,
        events: events,
        onEventTap: onEventTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'es').format(month);
    final title =
        '${monthName[0].toUpperCase()}${monthName.substring(1)} · ${events.length} eventos';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTypography.displaySmall()),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: events.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return EventCard(
                    event: event,
                    onTap: () => onEventTap(event),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Hoja inferior con todos los eventos de un día concreto.
class DayEventsSheet extends StatelessWidget {
  const DayEventsSheet({
    super.key,
    required this.day,
    required this.events,
    required this.onEventTap,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required List<CalendarEvent> events,
    required ValueChanged<CalendarEvent> onEventTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DayEventsSheet(
        day: day,
        events: events,
        onEventTap: onEventTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEEE d MMMM', 'es').format(day);
    final title =
        '${dayLabel[0].toUpperCase()}${dayLabel.substring(1)} · ${events.length} eventos';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: events.length <= 3 ? 0.45 : 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTypography.displaySmall()),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: events.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return EventCard(
                    event: event,
                    highlighted: isSameCalendarDayAsToday(day),
                    onTap: () => onEventTap(event),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
