import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../topic_detail_typography.dart';
import '../utils/season_hub_context.dart';

/// Barra de contexto al abrir un tema de temporada → vuelve al hub.
class SeasonHubContextBar extends StatelessWidget {
  const SeasonHubContextBar({
    super.key,
    required this.forumId,
    required this.seasonKey,
  });

  final String forumId;
  final String seasonKey;

  @override
  Widget build(BuildContext context) {
    final label = seasonHubLabel(seasonKey);
    final hubTopicId = seasonHubTopicId(seasonKey);
    if (label == null || hubTopicId == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/foros/$forumId/tema/$hubTopicId'),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.burgundy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.burgundy.withValues(alpha: 0.16),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.burgundy,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temas de $label',
                        style: TopicDetailTypography.body(
                          color: AppColors.burgundy,
                        ).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Volver al espacio de $label',
                        style: TopicDetailTypography.meta(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.burgundy.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
