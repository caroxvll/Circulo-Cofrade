import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../forums/hermandad_season_acts_provider.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../../forums/utils/hermandad_season_acts.dart';
import '../../forums/widgets/hermandad_season_acts_card.dart';
import '../../forums/widgets/hermandad_season_profile_sheet.dart';
import '../junta_ui.dart';

class JuntaSeasonActsTab extends ConsumerStatefulWidget {
  const JuntaSeasonActsTab({super.key});

  @override
  ConsumerState<JuntaSeasonActsTab> createState() =>
      _JuntaSeasonActsTabState();
}

class _JuntaSeasonActsTabState extends ConsumerState<JuntaSeasonActsTab> {
  final _search = TextEditingController();
  String? _day;
  SeasonActPasoFilter? _paso;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        data: (coverage) => _CoverageList(
          coverage: coverage,
          query: _search.text,
          selectedDay: _day,
          pasoFilter: _paso,
          searchController: _search,
          onQueryChanged: (_) => setState(() {}),
          onClearQuery: () {
            _search.clear();
            setState(() {});
          },
          onDayChanged: (day) => setState(() => _day = day),
          onPasoChanged: (filter) => setState(() => _paso = filter),
        ),
      ),
    );
  }
}

class _CoverageList extends StatelessWidget {
  const _CoverageList({
    required this.coverage,
    required this.query,
    required this.selectedDay,
    required this.pasoFilter,
    required this.searchController,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onDayChanged,
    required this.onPasoChanged,
  });

  final HermandadSeasonActsCoverage coverage;
  final String query;
  final String? selectedDay;
  final SeasonActPasoFilter? pasoFilter;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onDayChanged;
  final ValueChanged<SeasonActPasoFilter?> onPasoChanged;

  @override
  Widget build(BuildContext context) {
    final filtered = filterSeasonActsCoverage(
      rows: coverage.rows,
      query: query,
      processionDay: selectedDay,
      pasoFilter: pasoFilter,
    );
    final pasoCounts = <SeasonActPasoFilter, int>{
      for (final filter in SeasonActPasoFilter.values)
        filter: coverage.rows.where((row) => row.matchesPasoFilter(filter)).length,
    };
    final visible = HermandadSeasonActsCoverage(
      year: coverage.year,
      rows: filtered,
    );
    final dayCounts = <String, int>{};
    for (final row in coverage.rows) {
      final day = row.processionDay;
      if (day == null || day.isEmpty) continue;
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }

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
          'Cristo, Virgen o ambas en igualá y ensayos. '
          'Busca por hermandad o filtra por día y por paso.',
          style: JuntaUi.body(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar hermandad…',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: query.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar',
                    onPressed: onClearQuery,
                    icon: const Icon(Icons.close, size: 18),
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            hintStyle: JuntaUi.caption(),
          ),
          style: JuntaUi.body(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _DayChip(
                label: 'Todos',
                count: coverage.rows.length,
                selected: selectedDay == null,
                onTap: () => onDayChanged(null),
              ),
              const SizedBox(width: 6),
              for (final day in hermandadDirectoryDays) ...[
                _DayChip(
                  label: hermandadDayShortLabel(day),
                  count: dayCounts[day] ?? 0,
                  selected: selectedDay == day,
                  onTap: () => onDayChanged(
                    selectedDay == day ? null : day,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final filter in SeasonActPasoFilter.values) ...[
                _DayChip(
                  label: filter.label,
                  count: pasoCounts[filter] ?? 0,
                  selected: pasoFilter == filter,
                  onTap: () => onPasoChanged(
                    pasoFilter == filter ? null : filter,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        if (selectedDay != null || pasoFilter != null) ...[
          const SizedBox(height: 8),
          Text(
            [
              ?selectedDay,
              ?pasoFilter?.label,
            ].join(' · '),
            style: JuntaUi.caption(color: AppColors.burgundy).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _SummaryChips(coverage: visible),
        const SizedBox(height: 16),
        if (coverage.rows.isEmpty)
          const JuntaEmptyPanel(
            icon: Icons.church_outlined,
            message: 'Sin tablones de hermandad',
            subtitle:
                'Cuando haya hermandades en el directorio, saldrán aquí.',
          )
        else if (filtered.isEmpty)
          JuntaEmptyPanel(
            icon: Icons.search_off_outlined,
            message: 'Ninguna hermandad coincide',
            subtitle: selectedDay == null && pasoFilter == null
                ? 'Prueba con otro nombre.'
                : 'Nada coincide con ese filtro.',
          )
        else
          for (final row in filtered) ...[
            _CoverageRow(
              snapshot: row,
              onConfigure: row.topicId == null
                  ? null
                  : () => showHermandadSeasonProfileSheet(
                        context,
                        topicId: row.topicId!,
                        hermandadName: row.hermandadName,
                      ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.burgundy : AppColors.textSecondary;
    return Material(
      color: selected
          ? AppColors.burgundy.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.burgundy.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: JuntaUi.caption(color: color).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: JuntaUi.caption(color: color).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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

class _CoverageRow extends ConsumerWidget {
  const _CoverageRow({required this.snapshot, this.onConfigure});

  final HermandadSeasonActsSnapshot snapshot;
  final VoidCallback? onConfigure;

  Color get _badgeColor {
    if (!snapshot.hasAccount) return AppColors.textMuted;
    if (snapshot.isEmpty) return AppColors.accentRed;
    if (snapshot.isComplete) return const Color(0xFF2E7D32);
    return AppColors.goldDark;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = snapshot.processionDay;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
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
                    child: InkWell(
                      onTap: snapshot.topicId == null
                          ? null
                          : () => context.push(
                                '/foros/hermandades/tema/${snapshot.topicId}',
                              ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.hermandadName,
                            style: JuntaUi.cardTitle(),
                          ),
                          if (day != null && day.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              day,
                              style: JuntaUi.caption(
                                color: hermandadDayAccentColor(day),
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                    if (onConfigure != null)
                      IconButton(
                        tooltip: 'Ajustar temporada',
                        onPressed: onConfigure,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        color: AppColors.burgundy,
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
                        child: _MiniMilestone(
                          milestone: milestone,
                          label: milestone.kind.shortLabelFor(snapshot.profile),
                          onOpen: () => openSeasonActEvents(
                            context,
                            ref,
                            events: milestone.events,
                            title:
                                '${snapshot.hermandadName} · ${milestone.kind.shortLabelFor(snapshot.profile)}',
                          ),
                          onOpenPaso: (slot) => openSeasonActEvents(
                            context,
                            ref,
                            events: eventsForPasoSlot(milestone, slot),
                            title:
                                '${snapshot.hermandadName} · ${milestone.kind.shortLabelFor(snapshot.profile)} ${slot.label}',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _MiniMilestone extends StatelessWidget {
  const _MiniMilestone({
    required this.milestone,
    required this.label,
    required this.onOpen,
    required this.onOpenPaso,
  });

  final HermandadSeasonActMilestone milestone;
  final String label;
  final VoidCallback onOpen;
  final ValueChanged<SeasonPasoSlot> onOpenPaso;

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
        InkWell(
          onTap: milestone.hasAny ? onOpen : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              children: [
                Icon(
                  milestone.isFilled
                      ? Icons.check_circle
                      : milestone.hasAny
                          ? Icons.timelapse
                          : Icons.radio_button_unchecked,
                  size: 16,
                  color: _color,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: JuntaUi.caption(color: AppColors.textPrimary).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (milestone.pasoSlots.isNotEmpty) ...[
          const SizedBox(height: 4),
          SeasonPasoSlotsRow(
            slots: milestone.pasoSlots,
            compact: true,
            onSlotTap: (slot) {
              if (slot.filled) onOpenPaso(slot);
            },
          ),
        ] else
          InkWell(
            onTap: milestone.hasAny ? onOpen : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(
                milestone.isFilled ? milestone.statusLabel : '—',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JuntaUi.caption().copyWith(fontSize: 9),
              ),
            ),
          ),
      ],
    );
  }
}
