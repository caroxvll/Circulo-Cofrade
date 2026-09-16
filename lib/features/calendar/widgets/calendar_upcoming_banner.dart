import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../models/calendar_upcoming_snapshot.dart';
import '../utils/calendar_event_utils.dart';
import 'event_card.dart';
import 'month_events_sheet.dart';

class CalendarUpcomingBanner extends StatelessWidget {
  const CalendarUpcomingBanner({
    super.key,
    required this.snapshot,
    required this.onEventTap,
  });

  final CalendarUpcomingSnapshot snapshot;
  final ValueChanged<CalendarEvent> onEventTap;

  void _openTodayEvents(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DayEventsSheet.show(
      context,
      day: today,
      events: snapshot.todayEvents,
      onEventTap: (event) {
        Navigator.pop(context);
        onEventTap(event);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasAny) return const SizedBox.shrink();

    final todayEvents = snapshot.todayEvents;
    final featuredToday = featuredEventForDay(todayEvents);
    final extraTodayCount =
        featuredToday == null ? 0 : todayEvents.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.hasEventToday && featuredToday != null) ...[
          _SectionHeader(
            icon: Icons.wb_sunny_outlined,
            title: 'Hoy en el calendario cofrade',
            accent: AppColors.burgundy,
            trailing: extraTodayCount > 0
                ? TextButton(
                    onPressed: () => _openTodayEvents(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.burgundy,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Ver todos (${todayEvents.length})',
                      style: AppTypography.labelSmall(
                        color: AppColors.burgundy,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          EventCard(
            event: featuredToday,
            highlighted: true,
            onTap: () => onEventTap(featuredToday),
          ),
          const SizedBox(height: 16),
        ],
        if (snapshot.hasEventTomorrow) ...[
          _TomorrowSection(
            events: snapshot.tomorrowEvents,
            onEventTap: onEventTap,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TomorrowSection extends StatelessWidget {
  const _TomorrowSection({
    required this.events,
    required this.onEventTap,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  void _openTomorrowEvents(BuildContext context) {
    final day = DateTime(
      events.first.date.year,
      events.first.date.month,
      events.first.date.day,
    );
    DayEventsSheet.show(
      context,
      day: day,
      events: events,
      onEventTap: (event) {
        Navigator.pop(context);
        onEventTap(event);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = featuredEventForDay(events);
    if (featured == null) return const SizedBox.shrink();

    final extraCount = events.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.nightlight_outlined,
          title: 'Mañana',
          accent: AppColors.goldDark,
          trailing: extraCount > 0
              ? TextButton(
                  onPressed: () => _openTomorrowEvents(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.goldDark,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Ver todos (${events.length})',
                    style: AppTypography.labelSmall(
                      color: AppColors.goldDark,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        EventCard(
          event: featured,
          onTap: () => onEventTap(featured),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accent,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleLarge().copyWith(fontSize: 15, color: accent),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
