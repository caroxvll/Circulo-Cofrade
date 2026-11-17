import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../forums/hermandad_season_acts_provider.dart';
import '../../forums/utils/hermandad_season_acts.dart';
import '../junta_ui.dart';

class JuntaSeasonActsTab extends ConsumerWidget {
  const JuntaSeasonActsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hermandadSeasonActsCoverageProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(hermandadSeasonActsCoverageProvider);
        ref.invalidate(seasonActsEventsProvider);
        await ref.read(hermandadSeasonActsCoverageProvider.future);
      },
      child: async.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: JuntaUi.listPadding,
          children: const [
            SizedBox(height: 80),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: JuntaUi.listPadding,
          children: [
            Text(
              'No se pudo cargar la cobertura de actos.',
              style: JuntaUi.body(),
            ),
          ],
        ),
        data: (coverage) => _CoverageList(coverage: coverage),
      ),
    );
  }
}

class _CoverageList extends StatelessWidget {
  const _CoverageList({required this.coverage});

  final HermandadSeasonActsCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final rows = coverage.rows;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: JuntaUi.listPadding,
      children: [
        Text(
          'Actos de temporada ${coverage.year}',
          style: JuntaUi.moduleTitle(),
        ),
        const SizedBox(height: 4),
        Text(
          'Igualá, ensayos, muda y desarmá por hermandad. '
          'Sirve para ver a quién falta meter datos.',
          style: JuntaUi.body(),
        ),
        const SizedBox(height: 14),
        _SummaryChips(coverage: coverage),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const JuntaEmptyPanel(
            icon: Icons.church_outlined,
            message: 'Sin tablones de hermandad',
            subtitle:
                'Cuando haya hermandades en el directorio, saldrán aquí.',
          )
        else
          for (final row in rows) ...[
            _CoverageRow(snapshot: row),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({required this.coverage});

  final HermandadSeasonActsCoverage coverage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          label: 'Sin cuenta',
          count: coverage.missingAccount.length,
          color: AppColors.textMuted,
        ),
        _StatChip(
          label: 'Vacías',
          count: coverage.emptyActs.length,
          color: AppColors.accentRed,
        ),
        _StatChip(
          label: 'Parciales',
          count: coverage.partial.length,
          color: AppColors.goldDark,
        ),
        _StatChip(
          label: 'Completas',
          count: coverage.complete.length,
          color: const Color(0xFF2E7D32),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count $label',
        style: JuntaUi.caption(color: color).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.snapshot});

  final HermandadSeasonActsSnapshot snapshot;

  Color get _badgeColor {
    if (!snapshot.hasAccount) return AppColors.textMuted;
    if (snapshot.isEmpty) return AppColors.accentRed;
    if (snapshot.isComplete) return const Color(0xFF2E7D32);
    return AppColors.goldDark;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        onTap: snapshot.topicId == null
            ? null
            : () => context.push('/foros/hermandades/tema/${snapshot.topicId}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: JuntaUi.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.hermandadName,
                        style: JuntaUi.cardTitle(),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        snapshot.coverageLabel,
                        style: JuntaUi.caption(color: _badgeColor).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final milestone in snapshot.milestones)
                      Expanded(
                        child: _MiniMilestone(milestone: milestone),
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

class _MiniMilestone extends StatelessWidget {
  const _MiniMilestone({required this.milestone});

  final HermandadSeasonActMilestone milestone;

  Color get _color => switch (milestone.status) {
    HermandadSeasonActStatus.empty => AppColors.textMuted,
    HermandadSeasonActStatus.upcoming => AppColors.goldDark,
    HermandadSeasonActStatus.done => const Color(0xFF2E7D32),
    HermandadSeasonActStatus.mixed => AppColors.burgundy,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          milestone.isFilled ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: _color,
        ),
        const SizedBox(height: 4),
        Text(
          milestone.kind.shortLabel,
          textAlign: TextAlign.center,
          style: JuntaUi.caption(color: AppColors.textPrimary).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
        Text(
          milestone.isFilled ? milestone.statusLabel : '—',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: JuntaUi.caption().copyWith(fontSize: 9),
        ),
      ],
    );
  }
}
