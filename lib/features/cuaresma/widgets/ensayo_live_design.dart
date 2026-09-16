import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../calendar/calendar_provider.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import '../../calendar/widgets/calendar_event_image.dart';
import '../../forums/topic_detail_typography.dart';
import '../models/event_live_update.dart';
import '../utils/ensayos_day_groups.dart';

const _ensayoLiveGreen = Color(0xFF2E7D32);
const _ensayoLiveGreenBg = Color(0x142E7D32);
const _ensayoLiveGreenBorder = Color(0x332E7D32);

String formatEnsayoLiveHeading(CalendarEvent event) {
  final date = formatCalendarDayHeading(event.date);
  final time = event.time ?? '';
  final end = eventEndDateTime(event);
  final endTime = end != null ? formatEventClockTime(end) : null;
  if (time.isEmpty) return date;
  if (endTime != null) {
    return '$date · $time – $endTime';
  }
  return '$date · $time';
}

String? ensayoLiveEndTimeLabel(CalendarEvent event) {
  final end = eventEndDateTime(event);
  if (end == null) return null;
  return formatEventClockTime(end);
}

class EnsayoLiveSectionHeader extends StatelessWidget {
  const EnsayoLiveSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _GoldAccentBar(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TopicDetailTypography.sectionTitle(),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TopicDetailTypography.sectionSubtitle()),
        ],
      ],
    );
  }
}

class _GoldAccentBar extends StatelessWidget {
  const _GoldAccentBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gold.withValues(alpha: 0.85),
            AppColors.goldDark,
          ],
        ),
      ),
    );
  }
}

class EnsayoStatusChip extends StatelessWidget {
  const EnsayoStatusChip({
    super.key,
    required this.event,
    this.compact = false,
  });

  final CalendarEvent event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final timing = calendarEventTiming(event);
    final label = ensayoStatusLabel(event);
    final style = _chipStyle(timing?.kind, label);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label,
        style: TopicDetailTypography.meta(
          color: style.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _EnsayoChipStyle _chipStyle(CalendarEventTimingKind? kind, String label) {
    if (kind == CalendarEventTimingKind.inProgress) {
      return const _EnsayoChipStyle(
        foreground: _ensayoLiveGreen,
        background: _ensayoLiveGreenBg,
        border: _ensayoLiveGreenBorder,
      );
    }
    if (kind == CalendarEventTimingKind.startsSoon) {
      return const _EnsayoChipStyle(
        foreground: AppColors.goldDark,
        background: Color(0x14CFA74A),
        border: Color(0x33CFA74A),
      );
    }
    if (label == 'Finalizado') {
      return const _EnsayoChipStyle(
        foreground: AppColors.textMuted,
        background: AppColors.backgroundElevated,
        border: AppColors.border,
      );
    }
    return const _EnsayoChipStyle(
      foreground: AppColors.textSecondary,
      background: AppColors.backgroundElevated,
      border: AppColors.border,
    );
  }
}

class _EnsayoChipStyle {
  const _EnsayoChipStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

class EnsayoPremiumRow extends ConsumerWidget {
  const EnsayoPremiumRow({
    super.key,
    required this.event,
    required this.onTap,
    this.showChevron = true,
    this.muted = false,
  });

  final CalendarEvent event;
  final VoidCallback onTap;
  final bool showChevron;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = calendarEventTiming(event);
    final isLive = timing?.kind == CalendarEventTimingKind.inProgress;
    final textColor = muted ? AppColors.textMuted : AppColors.textPrimary;
    final logos = ref.watch(organizerLogosMapProvider).asData?.value;
    final shieldUrl = resolvedOrganizerShieldUrl(logos, event);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: isLive
                ? AppColors.burgundy.withValues(alpha: 0.03)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLive
                  ? AppColors.burgundy.withValues(alpha: 0.16)
                  : AppColors.gold.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  color: isLive
                      ? AppColors.burgundy.withValues(alpha: 0.55)
                      : AppColors.gold.withValues(alpha: 0.45),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          event.time ?? '--:--',
                          style: TopicDetailTypography.meta(
                            color: muted
                                ? AppColors.textMuted
                                : AppColors.burgundyDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                EventTypeIcon(
                                  type: event.type,
                                  size: 28,
                                  customIconUrl: shieldUrl,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    event.title,
                                    style: TopicDetailTypography.body(
                                      color: textColor,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              ensayoCompactSubtitle(event),
                              style: TopicDetailTypography.meta(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      EnsayoStatusChip(event: event, compact: true),
                      if (showChevron) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textMuted.withValues(alpha: 0.75),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnsayoLiveEventHero extends ConsumerWidget {
  const EnsayoLiveEventHero({super.key, required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = calendarEventTiming(event);
    final statusLabel = ensayoStatusLabel(event);
    final logos = ref.watch(organizerLogosMapProvider).asData?.value;
    final shieldUrl = resolvedOrganizerShieldUrl(logos, event);
    final hasCover = CalendarEventImage.hasDisplayableCover(event);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.burgundyDark,
                  AppColors.burgundy.withValues(alpha: 0.7),
                  AppColors.gold.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          Stack(
            children: [
              if (hasCover)
                Positioned.fill(
                  child: CalendarEventImage(
                    event: event,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    showTypeFallback: false,
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: hasCover
                          ? [
                              AppColors.surface.withValues(alpha: 0.78),
                              AppColors.surface.withValues(alpha: 0.92),
                              AppColors.surface.withValues(alpha: 0.97),
                            ]
                          : const [
                              AppColors.surface,
                              AppColors.surface,
                            ],
                      stops: hasCover ? const [0.0, 0.55, 1.0] : null,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _EnsayoLiveTrackingBadge(
                          event: event,
                          timing: timing,
                          statusLabel: statusLabel,
                        ),
                        const Spacer(),
                        EnsayoStatusChip(event: event),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EnsayoLiveOrganizerShield(
                          event: event,
                          shieldUrl: shieldUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: TopicDetailTypography.title(),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatEnsayoLiveHeading(event),
                                style: TopicDetailTypography.meta(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (timing?.kind ==
                                  CalendarEventTimingKind.inProgress) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Seguimiento activo hasta las ${ensayoLiveEndTimeLabel(event) ?? '--:--'}',
                                  style: TopicDetailTypography.meta(
                                    color: _ensayoLiveGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else if (timing != null &&
                                  timing.kind ==
                                      CalendarEventTimingKind.startsSoon) ...[
                                const SizedBox(height: 4),
                                Text(
                                  timing.label,
                                  style: TopicDetailTypography.meta(
                                    color: AppColors.goldDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else if (statusLabel == 'Programado' &&
                                  event.time != null &&
                                  event.time!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  ensayoLiveEndTimeLabel(event) != null
                                      ? 'Disponible de ${event.time} a ${ensayoLiveEndTimeLabel(event)}'
                                      : 'Disponible desde las ${event.time}',
                                  style: TopicDetailTypography.meta(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ] else if (statusLabel == 'Finalizado') ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Avisos en modo histórico',
                                  style: TopicDetailTypography.meta(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                              if (event.organizerLabel != null &&
                                  event.organizerLabel!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  event.organizerLabel!,
                                  style: TopicDetailTypography.meta(),
                                ),
                              ],
                              if (event.location != null &&
                                  event.location!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.place_outlined,
                                      size: 13,
                                      color: AppColors.textMuted
                                          .withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        event.location!,
                                        style: TopicDetailTypography.meta(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnsayoLiveOrganizerShield extends StatelessWidget {
  const _EnsayoLiveOrganizerShield({
    required this.event,
    required this.shieldUrl,
  });

  final CalendarEvent event;
  final String? shieldUrl;

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: EventTypeIcon(
        type: event.type,
        size: _size,
        customIconUrl: shieldUrl ?? event.customIconUrl,
      ),
    );
  }
}

class _EnsayoLiveTrackingBadge extends StatelessWidget {
  const _EnsayoLiveTrackingBadge({
    required this.event,
    required this.timing,
    required this.statusLabel,
  });

  final CalendarEvent event;
  final CalendarEventTiming? timing;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final isLive = timing?.kind == CalendarEventTimingKind.inProgress;
    final isSoon = timing?.kind == CalendarEventTimingKind.startsSoon;
    final isFinished = statusLabel == 'Finalizado';

    final label = isLive
        ? 'En directo'
        : isSoon
            ? 'Seguimiento listo'
            : isFinished
                ? 'Histórico'
                : 'Seguimiento en vivo';

    final style = isLive
        ? const _TrackingBadgeStyle(
            foreground: _ensayoLiveGreen,
            background: _ensayoLiveGreenBg,
            border: _ensayoLiveGreenBorder,
          )
        : isSoon
            ? const _TrackingBadgeStyle(
                foreground: AppColors.goldDark,
                background: Color(0x14CFA74A),
                border: Color(0x33CFA74A),
              )
            : isFinished
                ? const _TrackingBadgeStyle(
                    foreground: AppColors.textMuted,
                    background: AppColors.backgroundElevated,
                    border: AppColors.border,
                  )
                : const _TrackingBadgeStyle(
                    foreground: AppColors.textSecondary,
                    background: AppColors.backgroundElevated,
                    border: AppColors.border,
                  );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            const _LivePulseDot(),
            const SizedBox(width: 6),
          ] else ...[
            Icon(
              isFinished ? Icons.history_rounded : Icons.sensors_outlined,
              size: 13,
              color: style.foreground,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TopicDetailTypography.meta(
              color: style.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingBadgeStyle {
  const _TrackingBadgeStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

class EnsayoLiveUpdateTile extends StatelessWidget {
  const EnsayoLiveUpdateTile({
    super.key,
    required this.update,
    required this.onOpenMaps,
    this.isLatest = false,
  });

  final EventLiveUpdate update;
  final VoidCallback? onOpenMaps;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final hasMap = update.hasCoordinates || update.placeLabel != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isLatest
              ? AppColors.burgundy.withValues(alpha: 0.03)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLatest
                ? AppColors.burgundy.withValues(alpha: 0.22)
                : AppColors.gold.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLatest) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ÚLTIMO AVISO',
                      style: TopicDetailTypography.meta(
                        color: AppColors.burgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    update.authorHandle,
                    style: TopicDetailTypography.authorHandle(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatTimeAgo(update.createdAt),
                  style: TopicDetailTypography.meta(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              update.message,
              style: TopicDetailTypography.body(),
            ),
            if (hasMap && onOpenMaps != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: onOpenMaps,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 14,
                        color: AppColors.burgundy,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        update.placeLabel ?? 'Ver en mapa',
                        style: TopicDetailTypography.meta(
                          color: AppColors.burgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EnsayoLiveComposeBar extends StatelessWidget {
  const EnsayoLiveComposeBar({
    super.key,
    required this.controller,
    required this.isPosting,
    required this.isLocating,
    required this.hasLocation,
    required this.onUseLocation,
    required this.onClearLocation,
    required this.onSubmit,
    this.hintText = '¿Dónde va ahora el ensayo?',
    this.locationLabel = 'Añadir ubicación',
    this.placeLabel,
  });

  final TextEditingController controller;
  final bool isPosting;
  final bool isLocating;
  final bool hasLocation;
  final VoidCallback onUseLocation;
  final VoidCallback onClearLocation;
  final VoidCallback onSubmit;
  final String hintText;
  final String locationLabel;
  final String? placeLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: hasLocation
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _EnsayoLocationAttachedChip(
                            label: placeLabel ?? 'Mi ubicación',
                            onClear: onClearLocation,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasLocation
                              ? _ensayoLiveGreenBg
                              : AppColors.backgroundElevated,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: hasLocation
                                ? _ensayoLiveGreenBorder
                                : AppColors.gold.withValues(alpha: 0.2),
                            width: hasLocation ? 1.5 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: controller,
                          maxLength: 280,
                          minLines: 1,
                          maxLines: 3,
                          style: TopicDetailTypography.body(),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TopicDetailTypography.meta(
                              color: AppColors.textMuted,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSubmit(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _EnsayoComposeIconButton(
                      onTap: isLocating
                          ? null
                          : hasLocation
                              ? onClearLocation
                              : onUseLocation,
                      isLoading: isLocating,
                      icon: hasLocation
                          ? Icons.location_on_rounded
                          : Icons.my_location_outlined,
                      tooltip: hasLocation
                          ? 'Quitar ubicación'
                          : locationLabel,
                      active: hasLocation,
                      activeUsesGreen: true,
                    ),
                    const SizedBox(width: 8),
                    _EnsayoComposeIconButton(
                      onTap: isPosting ? null : onSubmit,
                      isLoading: isPosting,
                      icon: Icons.send_rounded,
                      tooltip: 'Enviar aviso',
                      primary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnsayoLocationAttachedChip extends StatelessWidget {
  const _EnsayoLocationAttachedChip({
    required this.label,
    required this.onClear,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      decoration: BoxDecoration(
        color: _ensayoLiveGreenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ensayoLiveGreenBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: _ensayoLiveGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ubicación añadida · $label',
              style: TopicDetailTypography.meta(
                color: _ensayoLiveGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: AppColors.textMuted,
            tooltip: 'Quitar ubicación',
          ),
        ],
      ),
    );
  }
}

class EnsayoLiveClosedBar extends StatelessWidget {
  const EnsayoLiveClosedBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.lock_clock_outlined,
                size: 16,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ensayo finalizado. Ya no se pueden publicar avisos.',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnsayoLiveWaitingBar extends StatelessWidget {
  const EnsayoLiveWaitingBar({super.key, required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final time = event.time?.trim();
    final endTime = ensayoLiveEndTimeLabel(event);
    final message = time != null && time.isNotEmpty
        ? endTime != null
            ? 'Podrás publicar avisos de $time a $endTime (cuando empiece).'
            : 'Podrás publicar avisos cuando empiece el ensayo (a las $time).'
        : 'Podrás publicar avisos cuando empiece el ensayo.';

    return Material(
      color: AppColors.backgroundElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 16,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnsayoLiveEmptyState extends StatelessWidget {
  const EnsayoLiveEmptyState({super.key, required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final timing = calendarEventTiming(event);
    final isFinished = ensayoStatusLabel(event) == 'Finalizado';
    final isLive = timing?.kind == CalendarEventTimingKind.inProgress;
    final isWaiting = !isLive && !isFinished;

    final title = isFinished
        ? 'Sin avisos registrados'
        : isLive
            ? 'Sé el primero en situar el ensayo'
            : 'Aún no ha empezado';

    final subtitle = isFinished
        ? 'Este ensayo ya terminó.'
        : isWaiting
            ? 'Los avisos se habilitan al inicio del ensayo.'
            : 'Comparte calle, esquina o punto del recorrido.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Icon(
                isLive
                    ? Icons.radar_outlined
                    : isWaiting
                        ? Icons.hourglass_empty_rounded
                        : Icons.sensors_outlined,
                size: 32,
                color: AppColors.goldDark.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TopicDetailTypography.title(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TopicDetailTypography.meta(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot({this.color = _ensayoLiveGreen});

  final Color color;

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + (_controller.value * 0.55);
        final opacity = 1 - _controller.value;
        return SizedBox(
          width: 10,
          height: 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: opacity * 0.35),
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String ensayoLiveFeedSubtitle({
  required CalendarEvent event,
  required int updateCount,
}) {
  if (updateCount == 0) {
    if (!ensayoLiveAllowsPosting(event)) {
      return 'Se activará al inicio del ensayo';
    }
    return 'Feed comunitario en tiempo real';
  }
  return updateCount == 1
      ? '1 aviso · más reciente arriba'
      : '$updateCount avisos · más reciente arriba';
}

bool ensayoLiveAllowsPosting(CalendarEvent event, {DateTime? now}) {
  final timing = calendarEventTiming(event, now: now);
  return timing?.kind == CalendarEventTimingKind.inProgress;
}

String ensayoLiveComposeHint(CalendarEvent event) {
  final timing = calendarEventTiming(event);
  if (ensayoStatusLabel(event) == 'Finalizado') {
    return 'Ensayo finalizado';
  }
  if (timing?.kind == CalendarEventTimingKind.scheduled) {
    return 'Calle, esquina o punto del recorrido…';
  }
  return '¿Dónde va ahora el ensayo?';
}

class _EnsayoComposeIconButton extends StatelessWidget {
  const _EnsayoComposeIconButton({
    required this.onTap,
    required this.icon,
    required this.tooltip,
    this.isLoading = false,
    this.primary = false,
    this.active = false,
    this.activeUsesGreen = false,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final String tooltip;
  final bool isLoading;
  final bool primary;
  final bool active;
  final bool activeUsesGreen;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final BorderSide border;

    if (primary) {
      background = AppColors.burgundy;
      foreground = AppColors.textOnDark;
      border = BorderSide.none;
    } else if (active && activeUsesGreen) {
      background = _ensayoLiveGreenBg;
      foreground = _ensayoLiveGreen;
      border = const BorderSide(color: _ensayoLiveGreenBorder);
    } else if (active) {
      background = AppColors.burgundy.withValues(alpha: 0.1);
      foreground = AppColors.burgundy;
      border = BorderSide(color: AppColors.burgundy.withValues(alpha: 0.35));
    } else {
      background = AppColors.backgroundElevated;
      foreground = AppColors.burgundy;
      border = BorderSide(color: AppColors.gold.withValues(alpha: 0.28));
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: CircleBorder(side: border),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary
                          ? AppColors.textOnDark
                          : activeUsesGreen
                              ? _ensayoLiveGreen
                              : AppColors.burgundy,
                    ),
                  )
                : Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}
