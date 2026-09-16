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

String cuaresmaHubEnsayoTimingLabel(CalendarEvent event, {DateTime? now}) {
  final timing = calendarEventTiming(event, now: now);
  if (timing == null) return ensayoStatusLabel(event, now: now);

  return switch (timing.kind) {
    CalendarEventTimingKind.inProgress => 'En curso',
    CalendarEventTimingKind.startsSoon => timing.label.replaceFirst(
        'Empieza',
        'Sale',
      ),
    CalendarEventTimingKind.scheduled => timing.label,
  };
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
  });

  final String forumId;
  final String topicId;

  void _openEnsayo(BuildContext context, CalendarEvent event) {
    final eventId = event.id;
    if (eventId == null) return;
    context.push(
      '/foros/$forumId/tema/$topicId/ensayo/$eventId',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ensayosAsync = ref.watch(todayEnsayosProvider);

    return ensayosAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => CuaresmaHubElevatedCard(
        child: Text(
          'No se pudieron cargar los ensayos de hoy.',
          style: TopicDetailTypography.meta(color: AppColors.textSecondary),
        ),
      ),
      data: (ensayos) {
        final groups = groupTodayEnsayos(ensayos);
        final featured = pickFeaturedEnsayo(groups);
        final activeOthers =
            pickOtherActiveEnsayos(groups, featured: featured);
        final finishedToday =
            pickFinishedEnsayos(groups, featured: featured);
        final hasTodayEnsayos = groups.total > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (featured != null)
              _CuaresmaFeaturedLiveCard(
                event: featured,
                forumId: forumId,
                topicId: topicId,
                onOpen: () => _openEnsayo(context, featured),
              )
            else if (!hasTodayEnsayos)
              const _CuaresmaNoLiveHint()
            else if (finishedToday.isNotEmpty)
              _CuaresmaEnsayosListCard(
                title: finishedToday.length == 1
                    ? 'Ensayo de hoy'
                    : 'Ensayos de hoy',
                events: finishedToday,
                onTap: (event) => _openEnsayo(context, event),
                initiallyExpanded: finishedToday.length == 1,
              ),
            if (activeOthers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CuaresmaEnsayosListCard(
                title: proximosEnsayosCardTitle(activeOthers),
                events: activeOthers,
                onTap: (event) => _openEnsayo(context, event),
              ),
            ],
            if (featured != null && finishedToday.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CuaresmaEnsayosListCard(
                title: finishedToday.length == 1
                    ? 'Ensayo finalizado'
                    : 'Ensayos finalizados',
                events: finishedToday,
                onTap: (event) => _openEnsayo(context, event),
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
    required this.forumId,
    required this.topicId,
    required this.onOpen,
  });

  final CalendarEvent event;
  final String forumId;
  final String topicId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = calendarEventTiming(event);
    final isLive = timing?.kind == CalendarEventTimingKind.inProgress;
    final logos = ref.watch(organizerLogosMapProvider).asData?.value;
    final shieldUrl = resolvedOrganizerShieldUrl(logos, event);
    final updatesAsync = event.id == null
        ? null
        : ref.watch(eventLiveUpdatesProvider(event.id!));

    final followers = updatesAsync?.asData?.value
            .map((u) => u.userId)
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
                        const SizedBox(width: 8),
                        CuaresmaHubPrimaryPillButton(
                          label: 'Seguir recorrido',
                          compact: true,
                          onPressed: onOpen,
                        ),
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
      child: Row(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 22,
            color: AppColors.textMuted.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hoy no hay ensayos en directo. Cuando empiecen, aparecerán aquí.',
              style: TopicDetailTypography.meta(
                color: AppColors.textSecondary,
              ),
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
