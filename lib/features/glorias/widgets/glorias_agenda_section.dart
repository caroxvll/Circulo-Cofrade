import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../calendar/calendar_provider.dart';
import '../../calendar/models/calendar_focus_request.dart';
import '../../cuaresma/widgets/cuaresma_hub_design.dart';
import '../../forums/topic_detail_typography.dart';
import '../glorias_provider.dart';

const _visibleAgendaCount = 5;

class GloriasAgendaPanel extends ConsumerWidget {
  const GloriasAgendaPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(gloriasUpcomingEventsProvider);

    return agendaAsync.when(
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
          'No se pudo cargar la agenda.',
          style: TopicDetailTypography.meta(color: AppColors.textSecondary),
        ),
      ),
      data: (events) {
        final visible = events.take(_visibleAgendaCount).toList();
        final hasMore = events.length > _visibleAgendaCount;

        return CuaresmaHubElevatedCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Próximas glorias',
                      style: TopicDetailTypography.body().copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  CuaresmaHubTextLink(
                    label: hasMore ? 'Ver calendario' : 'Calendario',
                    onPressed: () => context.go('/calendario'),
                  ),
                ],
              ),
              if (events.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'No hay glorias publicadas en los próximos meses. '
                  'Consulta el calendario o abre un tema en la tertulia.',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                ...visible.map(
                  (event) => _GloriasAgendaRow(
                    event: event,
                    onTap: () => _openEventInCalendar(context, ref, event),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

void _openEventInCalendar(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) {
  ref.read(calendarFocusRequestProvider.notifier).setFocus(
        CalendarFocusRequest(
          month: DateTime(event.date.year, event.date.month),
          day: event.date.day,
          event: event,
        ),
      );
  context.go('/calendario');
}

class _GloriasAgendaRow extends StatelessWidget {
  const _GloriasAgendaRow({
    required this.event,
    required this.onTap,
  });

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _capitalize(
      DateFormat("EEE d MMM", 'es').format(event.date),
    );
    final time = event.time?.trim();
    final place = event.location?.trim();
    final metaParts = <String>[
      if (time != null && time.isNotEmpty) time,
      if (place != null && place.isNotEmpty) place,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.burgundy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dateLabel,
                textAlign: TextAlign.center,
                style: TopicDetailTypography.meta(
                  color: AppColors.burgundy,
                  fontWeight: FontWeight.w700,
                ).copyWith(fontSize: 11, height: 1.2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title.trim().isEmpty ? 'Gloria' : event.title.trim(),
                    style: TopicDetailTypography.body().copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      metaParts.join(' · '),
                      style: TopicDetailTypography.meta(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
