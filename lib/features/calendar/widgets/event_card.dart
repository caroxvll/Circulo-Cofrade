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
    final time = eventThumbTime(event) == null
        ? null
        : _formatTimeCompact(eventThumbTime(event)!);
    final schedule = eventScheduleLabel(event);
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
            color: AppColors.burgundyDark.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(event: event, time: time),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Kicker(
                        kind: kind,
                        timing: timing,
                        admission: event.admissionChip,
                      ),
                    ),
                    if (showBookmark)
                      IconButton(
                        onPressed: onBookmarkToggle,
                        icon: Icon(
                          isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: isBookmarked
                              ? AppColors.burgundy
                              : AppColors.textMuted,
                          size: CalendarDesign.eventBookmarkSize,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
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
                if (schedule != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    schedule,
                    style: AppTypography.bodyMedium(
                      color: AppColors.textSecondary,
                    ).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                            color: AppColors.textSecondary,
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
                  SizedBox(height: organizer != null ? 3 : 8),
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

class _Kicker extends StatelessWidget {
  const _Kicker({
    required this.kind,
    required this.timing,
    required this.admission,
  });

  final String kind;
  final CalendarEventTiming? timing;
  final String? admission;

  @override
  Widget build(BuildContext context) {
    final pieces = <Widget>[];
    if (kind.isNotEmpty) {
      pieces.add(
        Text(
          kind.toUpperCase(),
          style: AppTypography.labelSmall(color: AppColors.goldDark).copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: 0.85,
          ),
        ),
      );
    }
    if (timing != null) {
      pieces.add(_TimingMark(timing: timing!));
    }
    final price = admission?.trim() ?? '';
    if (price.isNotEmpty) {
      pieces.add(
        Text(
          price,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall(color: AppColors.goldDark).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
      );
    }
    if (pieces.isEmpty) return const SizedBox(height: 14);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 7,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < pieces.length; i++) ...[
            if (i > 0)
              Text(
                '·',
                style: AppTypography.labelSmall(color: AppColors.goldLight)
                    .copyWith(fontSize: 12, height: 1),
              ),
            pieces[i],
          ],
        ],
      ),
    );
  }
}

class _TimingMark extends StatelessWidget {
  const _TimingMark({required this.timing});

  final CalendarEventTiming timing;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        const SizedBox(width: 5),
        Text(
          timing.label,
          style: AppTypography.labelSmall(color: timing.color).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.event, required this.time});

  final CalendarEvent event;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final clock = time?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(CalendarDesign.eventThumbRadius),
      child: SizedBox(
        width: CalendarDesign.eventThumbWidth,
        height: CalendarDesign.eventThumbHeight,
        child: Column(
          children: [
            Expanded(
              child: CalendarEventImage(
                event: event,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                compact: true,
                showTypeFallback: false,
                expand: true,
              ),
            ),
            if (clock.isNotEmpty)
              Container(
                width: double.infinity,
                color: AppColors.burgundy,
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      clock,
                      style: AppTypography.displaySmall(
                        color: AppColors.textOnDark,
                      ).copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 1),
                    Text(
                      'h',
                      style: AppTypography.displaySmall(
                        color: AppColors.goldPale,
                      ).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
        Icon(icon, size: 14, color: AppColors.goldDark),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium(
              color: AppColors.textSecondary,
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
