import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../forums/topic_detail_typography.dart';
import '../cuaresma_ensayos_provider.dart';
import '../utils/ensayos_day_groups.dart';
import 'cuaresma_hub_design.dart';
import 'ensayo_live_design.dart';

const _listMaxHeight = 280.0;
const _rowHeight = 54.0;

/// Lista de ensayos del día para el hub de Cuaresma o incrustada en otro sitio.
class CuaresmaEnsayosPanel extends ConsumerStatefulWidget {
  const CuaresmaEnsayosPanel({
    super.key,
    required this.forumId,
    required this.topicId,
    this.embedded = false,
  });

  final String forumId;
  final String topicId;
  final bool embedded;

  @override
  ConsumerState<CuaresmaEnsayosPanel> createState() =>
      _CuaresmaEnsayosPanelState();
}

class _CuaresmaEnsayosPanelState extends ConsumerState<CuaresmaEnsayosPanel> {
  bool _showFinished = false;

  void _openEnsayo(CalendarEvent event) {
    final eventId = event.id;
    if (eventId == null) return;
    context.push(
      '/foros/${widget.forumId}/tema/${widget.topicId}/ensayo/$eventId',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ensayosAsync = ref.watch(todayEnsayosProvider);

    return ensayosAsync.when(
      data: (ensayos) => _buildContent(ensayos),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No se pudieron cargar los ensayos de hoy.',
          style: TopicDetailTypography.meta(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildContent(List<CalendarEvent> ensayos) {
    final groups = groupTodayEnsayos(ensayos);
    final active = groups.featured;
    final pending = groups.compactList;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnsayoLiveSectionHeader(
          title: 'Ensayos del día',
          subtitle: ensayos.isEmpty
              ? null
              : groups.total == 1
                  ? '1 ensayo hoy · seguimiento en directo'
                  : '${groups.total} ensayos hoy · seguimiento en directo',
          trailing: ensayos.isEmpty ? null : _CountBadge(count: groups.total),
        ),
        if (ensayos.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (active.isNotEmpty) ...[
            ...active.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: EnsayoPremiumRow(
                  event: event,
                  onTap: () => _openEnsayo(event),
                ),
              ),
            ),
            if (pending.isNotEmpty) const SizedBox(height: 4),
          ],
          if (pending.isNotEmpty)
            _EnsayoScrollList(events: pending, onTap: _openEnsayo),
          if (groups.finished.isNotEmpty) ...[
            const SizedBox(height: 6),
            _FinishedToggle(
              count: groups.finished.length,
              expanded: _showFinished,
              onToggle: () => setState(() => _showFinished = !_showFinished),
            ),
            if (_showFinished) ...[
              const SizedBox(height: 6),
              _EnsayoScrollList(
                events: groups.finished,
                onTap: _openEnsayo,
                muted: true,
              ),
            ],
          ],
        ] else ...[
          const SizedBox(height: 8),
          const _EnsayosEmptyHint(),
        ],
      ],
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: CuaresmaHubElevatedCard(child: content),
      );
    }

    return CuaresmaHubElevatedCard(child: content);
  }
}

/// Compatibilidad con el hilo clásico (si se incrusta en otro sitio).
class CuaresmaEnsayosSection extends StatelessWidget {
  const CuaresmaEnsayosSection({
    super.key,
    required this.forumId,
    required this.topicId,
  });

  final String forumId;
  final String topicId;

  @override
  Widget build(BuildContext context) {
    return CuaresmaEnsayosPanel(
      forumId: forumId,
      topicId: topicId,
      embedded: true,
    );
  }
}

class _EnsayosEmptyHint extends StatelessWidget {
  const _EnsayosEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 16,
            color: AppColors.textMuted.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cuando haya ensayos en el calendario de hoy, '
              'aparecerán aquí para seguirlos en directo.',
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$count',
        style: TopicDetailTypography.meta(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EnsayoScrollList extends StatelessWidget {
  const _EnsayoScrollList({
    required this.events,
    required this.onTap,
    this.muted = false,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final listHeight = (events.length * _rowHeight)
        .clamp(_rowHeight, _listMaxHeight)
        .toDouble();

    return SizedBox(
      height: listHeight,
      child: Scrollbar(
        thumbVisibility: events.length > 4,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            return EnsayoPremiumRow(
              event: events[index],
              muted: muted,
              onTap: () => onTap(events[index]),
            );
          },
        ),
      ),
    );
  }
}

class _FinishedToggle extends StatelessWidget {
  const _FinishedToggle({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label =
        count == 1 ? '1 ensayo finalizado' : '$count ensayos finalizados';

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onToggle,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.textMuted,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TopicDetailTypography.meta()),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
