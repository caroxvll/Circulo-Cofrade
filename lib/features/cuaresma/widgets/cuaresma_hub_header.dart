import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../forums/topic_detail_typography.dart';
import 'cuaresma_hub_design.dart';

class CuaresmaHubHeroStack extends StatelessWidget {
  const CuaresmaHubHeroStack({
    super.key,
    required this.agendaLabel,
    required this.agendaLive,
    required this.topicsCount,
    required this.onNewTopic,
  });

  final String agendaLabel;
  final bool agendaLive;
  final int topicsCount;
  final VoidCallback onNewTopic;

  static final _fill = Color.alphaBlend(
    AppColors.goldPale.withValues(alpha: 0.72),
    AppColors.background,
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              AppColors.burgundy.withValues(alpha: 0.08),
              _fill,
            ),
            _fill,
            Color.alphaBlend(
              AppColors.gold.withValues(alpha: 0.12),
              AppColors.background,
            ),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -48,
              child: IgnorePointer(
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.burgundy.withValues(alpha: 0.055),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 54,
              bottom: -42,
              child: IgnorePointer(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.goldDark,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'AGENDA Y COMUNIDAD',
                        style: TopicDetailTypography.meta(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w800,
                        ).copyWith(fontSize: 9.5, letterSpacing: 1.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.burgundy.withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.burgundy.withValues(alpha: 0.13),
                          ),
                        ),
                        child: const Icon(
                          Icons.church_outlined,
                          size: 18,
                          color: AppColors.burgundy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hoy en Cuaresma',
                          style: AppTypography.newsHeadline(
                            color: AppColors.burgundyDark,
                          ).copyWith(fontSize: 26, height: 1),
                        ),
                      ),
                      CuaresmaHubNewTopicButton(onPressed: onNewTopic),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HubCountPill(
                        icon: Icons.campaign_outlined,
                        label: agendaLabel,
                        live: agendaLive,
                      ),
                      _HubCountPill(
                        icon: Icons.forum_outlined,
                        label: topicsCount == 1
                            ? '1 tema abierto'
                            : '$topicsCount temas abiertos',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCountPill extends StatelessWidget {
  const _HubCountPill({
    required this.icon,
    required this.label,
    this.live = false,
  });

  final IconData icon;
  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? const Color(0xFF1F7A52) : AppColors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: live
            ? const Color(0xFF2F9E6E).withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: live
              ? const Color(0xFF2F9E6E).withValues(alpha: 0.35)
              : AppColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TopicDetailTypography.meta(
                color: color,
                fontWeight: FontWeight.w600,
              ).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

