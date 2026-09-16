import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../cuaresma/widgets/cuaresma_hub_design.dart';
import '../../forums/topic_detail_typography.dart';
import '../semana_santa_provider.dart';
import 'ss_live_design.dart';

class SemanaSantaHubLiveSection extends ConsumerWidget {
  const SemanaSantaHubLiveSection({
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
    final feedAsync = ref.watch(ssLiveFeedProvider);

    return feedAsync.when(
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
          'No se pudieron cargar los avisos en directo.',
          style: TopicDetailTypography.meta(color: AppColors.textSecondary),
        ),
      ),
      data: (updates) {
        final preview = updates.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CuaresmaHubElevatedCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const CuaresmaHubLiveBadge(compact: true),
                      const Spacer(),
                      CuaresmaHubPrimaryPillButton(
                        label: 'Abrir en directo',
                        compact: true,
                        onPressed: () => _openLive(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Radar de la calle',
                    style: TopicDetailTypography.body().copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Retrasos, posición de hermandades, incidentes y curiosidades en tiempo real.',
                    style: TopicDetailTypography.meta(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (preview.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Aún no hay avisos. Sé el primero en contar qué pasa en la calle.',
                      style: TopicDetailTypography.meta(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    ...preview.map(
                      (u) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SsLiveUpdateTile(update: u, isLatest: false),
                      ),
                    ),
                    if (updates.length > preview.length)
                      Align(
                        alignment: Alignment.centerRight,
                        child: CuaresmaHubTextLink(
                          label: 'Ver todos (${updates.length})',
                          onPressed: () => _openLive(context),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
