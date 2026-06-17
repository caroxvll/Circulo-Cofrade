import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.highlighted = false,
    this.onTap,
  });

  final CalendarEvent event;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM', 'es').format(event.date);

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? AppColors.gold : AppColors.border,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(type: event.type),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$dateLabel · ${event.title}',
                        style: AppTypography.titleLarge().copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.subtitle,
                  style: AppTypography.bodyMedium(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.time != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.time!,
                    style: AppTypography.labelSmall(color: AppColors.burgundy)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                if (event.publisherHandle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.publisherHandle!,
                    style: AppTypography.labelSmall(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          EventTypeIcon(type: event.type, size: 52),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final EventType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: AppTypography.labelSmall(color: AppColors.burgundy)
            .copyWith(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
