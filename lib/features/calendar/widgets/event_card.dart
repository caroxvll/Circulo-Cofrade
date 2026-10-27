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
    final organizer = resolvedOrganizerLabel(logos, event);
    final shieldUrl = resolvedOrganizerShieldUrl(logos, event);
    final timing = calendarEventTiming(event);
    final time = event.time == null ? null : _formatTimeCompact(event.time!);
    final kind = event.calendarCellLabel.trim();
    final storedPlace = event.location?.trim() ?? '';
    final subtitle = event.subtitle.trim();
    final location = storedPlace.isNotEmpty
        ? storedPlace
        : (subtitle.isNotEmpty ? subtitle : null);
    final showPlace = location != null &&
        location.toLowerCase() != organizer?.trim().toLowerCase();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(event: event),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (time != null)
                      Text(
                        time,
                        style: AppTypography.displaySmall().copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: AppColors.burgundy,
                          letterSpacing: 0.2,
                        ),
                      ),
                    if (time != null && kind.isNotEmpty)
                      const SizedBox(width: 8),
                    if (kind.isNotEmpty)
                      Flexible(
                        fit: FlexFit.loose,
                        child: _KindChip(label: kind),
                      ),
                    if (timing != null) ...[
                      const SizedBox(width: 6),
                      _TimingBadge(timing: timing),
                    ],
                    const Spacer(),
                    if (showBookmark)
                      IconButton(
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: CalendarDesign.eventTitle(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (organizer != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _OrganizerShield(
                        shieldUrl: shieldUrl,
                        type: event.type,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          organizer,
                          style: AppTypography.bodyMedium(
                            color: AppColors.textPrimary,
                          ).copyWith(
                            fontSize: CalendarDesign.eventMetaSize,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (showPlace) ...[
                  const SizedBox(height: 4),
                  _MetaLine(
                    icon: Icons.location_on_outlined,
                    text: location,
                  ),
                ],
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

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall(color: AppColors.burgundy).copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
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
        size: 16,
        customIconUrl: shieldUrl,
      );
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: EventTypeIcon(type: type, size: 16),
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
        Icon(icon, size: 13, color: AppColors.textMuted),
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
