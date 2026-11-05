import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import '../../cuaresma/cuaresma_ensayos_provider.dart';
import '../../cuaresma/utils/cuaresma_topic.dart';

const _liveGreen = Color(0xFF2E7D32);
const _circuloForumId = 'foro-cofradiero';

/// Banda fija de Para ti: lo de hoy que está en curso, sale pronto o es el próximo.
class ParaTiLiveEventsBand extends ConsumerWidget {
  const ParaTiLiveEventsBand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(todayParaTiLiveEventsProvider).asData?.value ??
        const <CalendarEvent>[];
    if (events.isEmpty) return const SizedBox.shrink();

    final anyLive = events.any(_isLive);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              if (anyLive) ...[
                const _LiveDot(),
                const SizedBox(width: 6),
              ],
              Text(
                anyLive ? 'EN VIVO' : 'HOY',
                style: AppTypography.labelSmall(
                  color: anyLive ? _liveGreen : AppColors.goldDark,
                ).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.7,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        if (events.length == 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: _LiveEventChip(event: events.first, expanded: true),
          )
        else
          SizedBox(
            height: 74,
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) => true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _LiveEventChip(event: events[index]);
                },
              ),
            ),
          ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }
}

class _LiveEventChip extends StatelessWidget {
  const _LiveEventChip({
    required this.event,
    this.expanded = false,
  });

  final CalendarEvent event;
  final bool expanded;

  static final _fill = Color.alphaBlend(
    AppColors.goldPale.withValues(alpha: 0.72),
    AppColors.background,
  );

  @override
  Widget build(BuildContext context) {
    final live = _isLive(event);
    final name = _eventName(event);
    final timing = _timingLabel(event);
    final accent = live ? _liveGreen : AppColors.burgundy;

    return Material(
      color: _fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: expanded ? double.infinity : 196,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: live
                  ? _liveGreen.withValues(alpha: 0.4)
                  : AppColors.gold.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                EventTypeIcon(
                  type: event.type,
                  size: 36,
                  customIconUrl: event.customIconUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_typeLabel(event.type)} · $timing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall(
                          color: accent,
                        ).copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.hermandadName().copyWith(
                          fontSize: 16,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: accent,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final id = event.id;
    if (id == null || id.isEmpty) return;
    if (event.type == EventType.ensayo) {
      context.push(
        '/foros/$_circuloForumId/tema/$cuaresmaTopicId/ensayo/$id',
      );
      return;
    }
    context.push(
      '/foros/$_circuloForumId/tema/$cuaresmaTopicId?cita=$id',
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: _liveGreen,
        shape: BoxShape.circle,
      ),
    );
  }
}

bool _isLive(CalendarEvent event) {
  return calendarEventTiming(event)?.kind == CalendarEventTimingKind.inProgress;
}

String _eventName(CalendarEvent event) {
  final organizer = event.organizerLabel?.trim();
  if (organizer != null && organizer.isNotEmpty) return organizer;
  final title = event.title.trim();
  if (title.isNotEmpty) return title;
  return _typeLabel(event.type);
}

String _typeLabel(EventType type) {
  return switch (type) {
    EventType.ensayo => 'ENSAYO',
    EventType.iguala => 'IGUALÁ',
    EventType.concierto => 'CONCIERTO',
    _ => type.cellLabel.toUpperCase(),
  };
}

String _timingLabel(CalendarEvent event) {
  final timing = calendarEventTiming(event);
  final time = event.time?.trim();
  if (timing == null) {
    return (time != null && time.isNotEmpty) ? time : 'Hoy';
  }
  if (timing.kind == CalendarEventTimingKind.scheduled &&
      time != null &&
      time.isNotEmpty) {
    return time;
  }
  if (event.type == EventType.ensayo &&
      timing.kind == CalendarEventTimingKind.startsSoon) {
    return timing.label.replaceFirst('Empieza', 'Sale');
  }
  return timing.label;
}
