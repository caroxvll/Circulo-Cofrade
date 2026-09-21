import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../calendar_provider.dart';
import '../calendar_design_tokens.dart';
import '../utils/calendar_event_utils.dart';
import 'calendar_event_image.dart';

class EventCard extends ConsumerWidget {
  const EventCard({
    super.key,
    required this.event,
    this.highlighted = false,
    this.onTap,
    this.isBookmarked = false,
    this.onBookmarkToggle,
    this.showBookmark = true,
  });

  final CalendarEvent event;
  final bool highlighted;
  final VoidCallback? onTap;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;
  final bool showBookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logos = ref.watch(organizerLogosMapProvider).asData?.value;
    final location = event.location?.trim().isNotEmpty == true
        ? event.location!.trim()
        : event.subtitle;
    final organizer = resolvedOrganizerLabel(logos, event);
    final shieldUrl = resolvedOrganizerShieldUrl(logos, event);
    final timing = calendarEventTiming(event);
    final time = event.time == null ? null : _formatTimeCompact(event.time!);

    final card = Container(
      padding: const EdgeInsets.all(CalendarDesign.eventCardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(CalendarDesign.eventCardRadius),
        border: Border.all(
          color: highlighted
              ? AppColors.gold.withValues(alpha: 0.28)
              : AppColors.border.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Thumbnail(event: event),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (time != null) ...[
                      Text(
                        time,
                        style: AppTypography.displaySmall().copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: AppColors.burgundy,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        event.title,
                        style: CalendarDesign.eventTitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showBookmark)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton(
                          onPressed: onBookmarkToggle,
                          icon: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: AppColors.burgundy,
                            size: CalendarDesign.eventBookmarkSize,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ),
                  ],
                ),
                if (organizer != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _OrganizerShield(
                        shieldUrl: shieldUrl,
                        type: event.type,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          organizer,
                          style: AppTypography.bodyMedium(
                            color: AppColors.textSecondary,
                          ).copyWith(
                            fontSize: CalendarDesign.eventMetaSize,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: _MetaLine(
                        icon: Icons.location_on_outlined,
                        text: location,
                      ),
                    ),
                    if (timing != null) ...[
                      const SizedBox(width: 6),
                      _TimingBadge(timing: timing),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CalendarDesign.eventCardRadius),
        child: card,
      ),
    );
  }
}

String _formatTimeCompact(String time) {
  final trimmed = time.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.replaceAll('h', '').trim();
}

class _TimingBadge extends StatelessWidget {
  const _TimingBadge({required this.timing});

  final CalendarEventTiming timing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: timing.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: timing.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            timing.label,
            style: AppTypography.labelSmall(color: timing.color).copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CalendarDesign.eventThumbRadius),
      child: SizedBox(
        width: CalendarDesign.eventThumbWidth,
        height: CalendarDesign.eventThumbHeight,
        child: CalendarEventImage(
          event: event,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          borderRadius: BorderRadius.circular(CalendarDesign.eventThumbRadius),
          compact: true,
          showTypeFallback: false,
        ),
      ),
    );
  }
}

class _OrganizerShield extends StatelessWidget {
  const _OrganizerShield({
    required this.shieldUrl,
    required this.type,
  });

  final String? shieldUrl;
  final EventType type;

  @override
  Widget build(BuildContext context) {
    if (shieldUrl != null) {
      return EventTypeIcon(
        type: type,
        size: 14,
        customIconUrl: shieldUrl,
      );
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: EventTypeIcon(type: type, size: 14),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium(
              color: AppColors.textMuted,
            ).copyWith(
              fontSize: CalendarDesign.eventMetaSize,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
