import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../cuaresma/widgets/cuaresma_hub_design.dart';
import '../../forums/topic_detail_typography.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';
import 'ss_live_design.dart';

/// Timeline en directo (sin mapa · año 1).
class SemanaSantaRadarSection extends ConsumerWidget {
  const SemanaSantaRadarSection({
    super.key,
    required this.forumId,
    required this.topicId,
  });

  final String forumId;
  final String topicId;

  void _openLive(BuildContext context) {
    context.push('/foros/$forumId/tema/$topicId/en-directo');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hermandades = ref.watch(ssHermandadLabelsProvider);
    final selectedHermandad = ref.watch(ssHermandadFilterProvider);
    final kindFilter = ref.watch(ssLiveFeedFilterProvider);
    final feedAsync = ref.watch(ssLiveFeedProvider);
    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    final dayLabel = gate?.activeDay?.label;
    final sectionSubtitle = dayLabel != null
        ? 'Jornada: $dayLabel · últimas 12 h'
        : 'Últimas 12 h · seguimiento de hermandades';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: AppColors.goldDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'EN DIRECTO',
                style: TopicDetailTypography.sectionTitle(),
              ),
            ),
            const CuaresmaHubLiveBadge(compact: true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          sectionSubtitle,
          style: TopicDetailTypography.sectionSubtitle(),
        ),
        const SizedBox(height: 10),
        CuaresmaHubElevatedCard(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _KindChip(
                    label: 'Todos',
                    selected: kindFilter == null,
                    color: AppColors.burgundy,
                    icon: Icons.grid_view_rounded,
                    onTap: () =>
                        ref.read(ssLiveFeedFilterProvider.notifier).setFilter(null),
                  ),
                  for (final kind in SsLiveUpdateKind.values)
                    _KindChip(
                      label: kind.label,
                      selected: kindFilter == kind,
                      color: ssKindColor(kind),
                      icon: ssKindIcon(kind),
                      onTap: () {
                        final notifier =
                            ref.read(ssLiveFeedFilterProvider.notifier);
                        notifier.setFilter(kindFilter == kind ? null : kind);
                      },
                    ),
                ],
              ),
              if (hermandades.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: selectedHermandad,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  hint: Text(
                    'Todas las hermandades',
                    style: TopicDetailTypography.meta(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'Todas las hermandades',
                        style: TopicDetailTypography.meta(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final h in hermandades)
                      DropdownMenuItem<String?>(
                        value: h,
                        child: Text(
                          h,
                          style: TopicDetailTypography.meta(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => ref
                      .read(ssHermandadFilterProvider.notifier)
                      .setHermandad(value),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              feedAsync.when(
                data: (updates) {
                  if (updates.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            kindFilter == null && selectedHermandad == null
                                ? 'Todavía no hay avisos publicados.'
                                : 'Ningún aviso coincide con este filtro.',
                            textAlign: TextAlign.center,
                            style: TopicDetailTypography.meta(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openLive(context),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Publicar'),
                          ),
                        ],
                      ),
                    );
                  }
                  final preview = updates.take(8).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${updates.length} avisos',
                            style: TopicDetailTypography.meta(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (updates.length > preview.length)
                            CuaresmaHubTextLink(
                              label: 'Ver todos',
                              onPressed: () => _openLive(context),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final u in preview)
                        SsLiveUpdateTile(
                          update: u,
                          isLatest: u == preview.first,
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, _) => Text(
                  'No se pudieron cargar los avisos.',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : AppColors.backgroundElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TopicDetailTypography.meta(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
