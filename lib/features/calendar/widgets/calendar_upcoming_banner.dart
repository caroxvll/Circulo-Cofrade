import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../models/calendar_upcoming_snapshot.dart';
import 'event_card.dart';

class CalendarUpcomingBanner extends StatelessWidget {
  const CalendarUpcomingBanner({
    super.key,
    required this.snapshot,
    required this.onEventTap,
  });

  final CalendarUpcomingSnapshot snapshot;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasAny) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.hasEventToday) ...[
          _SectionHeader(
            icon: Icons.wb_sunny_outlined,
            title: 'Hoy en el calendario cofrade',
            accent: AppColors.burgundy,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < snapshot.todayEvents.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            EventCard(
              event: snapshot.todayEvents[i],
              highlighted: true,
              onTap: () => onEventTap(snapshot.todayEvents[i]),
            ),
          ],
          const SizedBox(height: 16),
        ],
        if (snapshot.hasEventTomorrow) ...[
          _SectionHeader(
            icon: Icons.nightlight_outlined,
            title: 'Mañana',
            accent: AppColors.goldDark,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < snapshot.tomorrowEvents.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            EventCard(
              event: snapshot.tomorrowEvents[i],
              onTap: () => onEventTap(snapshot.tomorrowEvents[i]),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleLarge().copyWith(fontSize: 15, color: accent),
        ),
      ],
    );
  }
}
