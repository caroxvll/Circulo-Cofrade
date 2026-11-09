import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../calendar/calendar_provider.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import '../../forums/topic_detail_typography.dart';
import '../cuaresma_ensayos_provider.dart';
import '../utils/ensayos_day_groups.dart';
import 'cuaresma_hub_design.dart';
import 'ensayo_live_design.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';

String cuaresmaHubEnsayoTimingLabel(CalendarEvent event, {DateTime? now}) {
  final timing = calendarEventTiming(event, now: now);
  if (timing == null) return ensayoStatusLabel(event, now: now);

  return switch (timing.kind) {
    CalendarEventTimingKind.inProgress => 'En curso',
    CalendarEventTimingKind.startsSoon => event.type == EventType.ensayo
        ? timing.label.replaceFirst('Empieza', 'Sale')
        : timing.label,
    CalendarEventTimingKind.scheduled => timing.label,
    CalendarEventTimingKind.finished => 'Finalizado',
  };
}

String cuaresmaHubAgendaLabel(
  List<CalendarEvent> events, {
  required int liveCount,
}) {
  if (events.isEmpty) return 'Sin citas hoy';
  if (events.every((event) => event.type == EventType.ensayo)) {
    if (liveCount > 0) {
      return liveCount == 1
          ? '1 ensayo en directo'
          : '$liveCount ensayos en directo';
    }
    return events.length == 1
        ? '1 ensayo hoy'
        : '${events.length} ensayos hoy';
  }

  final types = events.map((event) => event.type).toSet();
  if (types.length == 1) {
    final type = types.single;
    final count = liveCount > 0 ? liveCount : events.length;
    final noun = switch (type) {
      EventType.iguala => count == 1 ? 'igualá' : 'igualás',
      EventType.concierto => count == 1 ? 'concierto' : 'conciertos',
      _ => count == 1 ? 'cita' : 'citas',
    };
    if (liveCount > 0) {
      return count == 1 ? '1 $noun en directo' : '$count $noun en directo';
    }
    return count == 1 ? '1 $noun hoy' : '$count $noun hoy';
  }
  if (liveCount > 0) {
    return liveCount == 1 ? '1 en directo' : '$liveCount en directo';
  }
  return events.length == 1 ? '1 cita hoy' : '${events.length} citas hoy';
}

CalendarEvent? agendaEventById(EnsayosDayGroups groups, String? eventId) {
  if (eventId == null || eventId.isEmpty) return null;
  for (final event in [
    ...groups.live,
    ...groups.soon,
    ...groups.upcoming,
    ...groups.finished,
  ]) {
    if (event.id == eventId) return event;
  }
  return null;
}

CalendarEvent? pickFeaturedEnsayo(EnsayosDayGroups groups) {
  if (groups.live.isNotEmpty) return groups.live.first;
  if (groups.soon.isNotEmpty) return groups.soon.first;
  if (groups.upcoming.isNotEmpty) return groups.upcoming.first;
  return null;
}

List<CalendarEvent> pickOtherActiveEnsayos(
  EnsayosDayGroups groups, {
  CalendarEvent? featured,
}) {
  final featuredId = featured?.id;
  final list = <CalendarEvent>[
    ...groups.live,
    ...groups.soon,
    ...groups.upcoming,
  ];
  final seen = <String>{};
  final result = <CalendarEvent>[];
  for (final event in list) {
    final id = event.id;
    if (id == null || id == featuredId || seen.contains(id)) continue;
    seen.add(id);
    result.add(event);
  }
  return result;
}

List<CalendarEvent> pickFinishedEnsayos(
  EnsayosDayGroups groups, {
  CalendarEvent? featured,
}) {
  final featuredId = featured?.id;
  return groups.finished
      .where((event) => event.id != null && event.id != featuredId)
      .toList();
}

bool _onlyEnsayos(List<CalendarEvent> events) {
  return events.every((event) => event.type == EventType.ensayo);
}

String _activeTitle(List<CalendarEvent> events) {
  if (_onlyEnsayos(events)) return proximosEnsayosCardTitle(events);
  return 'También hoy';
}

String _finishedTitle(
  List<CalendarEvent> events, {
  required bool alongsideFeatured,
}) {
  if (_onlyEnsayos(events)) {
    if (!alongsideFeatured) {
      return events.length == 1 ? 'Ensayo de hoy' : 'Ensayos de hoy';
    }
    return events.length == 1 ? 'Ensayo finalizado' : 'Ensayos finalizados';
  }
  if (!alongsideFeatured) {
    return events.length == 1 ? 'Cita de hoy' : 'Citas de hoy';
  }
  return events.length == 1 ? 'Cita finalizada' : 'Citas finalizadas';
}

String _agendaTypeLabel(EventType type) {
  return switch (type) {
    EventType.ensayo => 'ENSAYO',
    EventType.iguala => 'IGUALÁ',
    EventType.concierto => 'CONCIERTO',
    _ => type.cellLabel.toUpperCase(),
  };
}

String proximosEnsayosCardTitle(List<CalendarEvent> events) {
  if (events.isEmpty) return 'Ensayos';
  final allFinished = events.every(
    (event) => ensayoStatusLabel(event) == 'Finalizado',
  );
  if (allFinished) {
    return events.length == 1 ? 'Ensayo de hoy' : 'Ensayos de hoy';
  }
  return events.length == 1 ? 'Próximo ensayo' : 'Próximos ensayos';
}

class CuaresmaHubLiveSection extends ConsumerWidget {
  const CuaresmaHubLiveSection({
    super.key,
    required this.forumId,
    required this.topicId,
    this.focusEventId,
  });

  final String forumId;
  final String topicId;
  final String? focusEventId;

  void _openEvent(BuildContext context, CalendarEvent event) {
    final eventId = event.id;
    if (eventId == null || eventId.isEmpty) return;
    if (event.type.opensCuaresmaLive) {
      context.push('/foros/$forumId/tema/$topicId/ensayo/$eventId');
      return;
    }
    context.replace('/foros/$forumId/tema/$topicId?cita=$eventId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(todayCuaresmaAgendaProvider);

    return agendaAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: HubSectionListSkeleton(),
      ),
      error: (_, _) => CuaresmaHubElevatedCard(
        child: Text(
          'No se pudieron cargar las citas de hoy.',
          style: TopicDetailTypography.meta(color: AppColors.textSecondary),
        ),
      ),
      data: (agenda) {
        final groups = groupTodayEnsayos(agenda);
        final featured =
            agendaEventById(groups, focusEventId) ?? pickFeaturedEnsayo(groups);
        final activeOthers =
            pickOtherActiveEnsayos(groups, featured: featured);
        final finishedToday =
            pickFinishedEnsayos(groups, featured: featured);
        final hasToday = groups.total > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (featured != null)
              _CuaresmaFeaturedLiveCard(
                event: featured,
                onOpen: featured.type.opensCuaresmaLive
                    ? () => _openEvent(context, featured)
                    : null,
              )
            else if (!hasToday)
              const _CuaresmaNoLiveHint()
            else if (finishedToday.isNotEmpty)
              _CuaresmaEnsayosListCard(
                title: _finishedTitle(
                  finishedToday,
                  alongsideFeatured: false,
                ),
                events: finishedToday,
                onTap: (event) => _openEvent(context, event),
                initiallyExpanded: finishedToday.length <= 3,
              ),
            if (activeOthers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CuaresmaEnsayosListCard(
                title: _activeTitle(activeOthers),
                events: activeOthers,
                onTap: (event) => _openEvent(context, event),
                initiallyExpanded: activeOthers.length <= 3,
              ),
            ],
            if (featured != null && finishedToday.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CuaresmaEnsayosListCard(
                title: _finishedTitle(
                  finishedToday,
                  alongsideFeatured: true,
                ),
                events: finishedToday,
                onTap: (event) => _openEvent(context, event),
                initiallyExpanded: finishedToday.length <= 3,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CuaresmaFeaturedLiveCard extends ConsumerWidget {
  const _CuaresmaFeaturedLiveCard({
    required this.event,
    required this.onOpen,
  });

  final CalendarEvent event;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = calendarEventTiming(event);
    final isLive = timing?.kind == CalendarEventTimingKind.inProgress;
    final opensLive = event.type.opensCuaresmaLive;
    final logos = ref.watch(organizerLogosMapProvider).asData?.value;
    final shieldUrl = resolvedOrganizerShieldUrl(logos, event);
    final updatesAsync = !opensLive || event.id == null
        ? null
        : ref.watch(eventLiveUpdatesProvider(event.id!));
    final followers = updatesAsync?.asData?.value
            .map((update) => update.userId)
            .toSet()
            .length ??
        0;

    final location = event.location?.trim();
    final organizer = event.organizerLabel?.trim();
    final subtitle = (organizer != null && organizer.isNotEmpty)
        ? organizer
        : event.title;

    return CuaresmaHubElevatedCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLive) ...[
            const CuaresmaHubLiveBadge(compact: true),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventTypeIcon(
                type: event.type,
                size: 40,
                customIconUrl: shieldUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.type != EventType.ensayo) ...[
                      Text(
                        _agendaTypeLabel(event.type),
                        style: TopicDetailTypography.meta(
                          color: AppColors.burgundy,
                          fontWeight: FontWeight.w800,
                        ).copyWith(fontSize: 10, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      subtitle,
                      style: TopicDetailTypography.body().copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: TopicDetailTypography.meta(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppColors.burgundy.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            cuaresmaHubEnsayoTimingLabel(event),
                            style: TopicDetailTypography.meta(
                              color: AppColors.burgundy,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onOpen != null) ...[
                          const SizedBox(width: 8),
                          CuaresmaHubPrimaryPillButton(
                            label: 'Seguir recorrido',
                            compact: true,
                            onPressed: onOpen!,
                          ),
                        ],
                      ],
                    ),
                    if (followers > 0) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            followers == 1
                                ? '1 persona siguiendo'
                                : '$followers personas siguiendo',
                            style: TopicDetailTypography.meta(
                              color: AppColors.textSecondary,
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
    );
  }
}

class _CuaresmaNoLiveHint extends StatelessWidget {
  const _CuaresmaNoLiveHint();

  @override
  Widget build(BuildContext context) {
    return CuaresmaHubElevatedCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.goldPale.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              size: 18,
              color: AppColors.burgundy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOY',
                  style: TopicDetailTypography.meta(
                    color: AppColors.burgundy,
                    fontWeight: FontWeight.w800,
                  ).copyWith(fontSize: 10, letterSpacing: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hoy no hay ensayos, igualás ni conciertos. Cuando salgan, aparecerán aquí.',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CuaresmaEnsayosListCard extends StatefulWidget {
  const _CuaresmaEnsayosListCard({
    required this.title,
    required this.events,
    required this.onTap,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onTap;
  final bool initiallyExpanded;

  @override
  State<_CuaresmaEnsayosListCard> createState() =>
      _CuaresmaEnsayosListCardState();
}

class _CuaresmaEnsayosListCardState extends State<_CuaresmaEnsayosListCard> {
  late var _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final count = widget.events.length;

    return CuaresmaHubElevatedCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: AppColors.burgundy.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TopicDetailTypography.body().copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TopicDetailTypography.meta(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.events.map(
              (event) => EnsayoPremiumRow(
                event: event,
                muted: ensayoStatusLabel(event) == 'Finalizado',
                showChevron: true,
                onTap: () => widget.onTap(event),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
