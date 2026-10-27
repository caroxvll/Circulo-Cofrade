import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_asset_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../../forums/data/topic_icon_assets.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/widgets/topic_card.dart';
import 'cuaresma_hub_design.dart';

class CuaresmaHubHeroStack extends StatelessWidget {
  const CuaresmaHubHeroStack({
    super.key,
    required this.topic,
    required this.liveEnsayoCount,
    required this.todayEnsayoCount,
    required this.topicsCount,
    required this.onNewTopic,
  });

  final ForumTopic topic;
  final int liveEnsayoCount;
  final int todayEnsayoCount;
  final int topicsCount;
  final VoidCallback onNewTopic;

  static const _heroHeight = 156.0;
  static const _overlap = 28.0;

  bool get _hasCoverBackground {
    final cover = topic.coverImageUrl?.trim();
    return cover != null && cover.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final cover = topic.coverImageUrl?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasCoverBackground && cover != null)
                topicCoverIsAsset(cover)
                    ? CofradeoAssetImage(
                        assetPath: cover,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: ImageDecodeCache.px(
                          context,
                          MediaQuery.sizeOf(context).width,
                        ),
                        fadeDuration: const Duration(milliseconds: 360),
                        errorBuilder: (_, _, _) =>
                            const _CuaresmaHeroFallback(),
                      )
                    : CofradeoNetworkImage(
                        url: cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: _heroHeight,
                        cacheSize: 720,
                        filterQuality: FilterQuality.medium,
                        fadeInDuration: const Duration(milliseconds: 360),
                        placeholder: const ColoredBox(
                          color: AppColors.burgundyDark,
                        ),
                        errorWidget: const _CuaresmaHeroFallback(),
                      )
              else
                const _CuaresmaHeroFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: (!topic.showHubTitle && _hasCoverBackground)
                        ? [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.18),
                            Colors.black.withValues(alpha: 0.42),
                          ]
                        : [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.78),
                          ],
                  ),
                ),
              ),
              // Título/icono opcionales (admin: show_hub_title).
              if (topic.showHubTitle)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PinnedTopicMark(
                        topic: topic,
                        size: 54,
                        circular: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.title,
                              style: TopicDetailTypography.title(
                                color: AppColors.textOnDark,
                              ).copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ensayos en directo · Comunidad cofrade',
                              style: TopicDetailTypography.meta(
                                color: AppColors.textOnDark.withValues(alpha: 0.88),
                              ).copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -_overlap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CuaresmaHubElevatedCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'HOY EN CUARESMA',
                          style: AppTypography.labelSmall(
                            color: AppColors.burgundy,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.1,
                            height: 1,
                          ),
                        ),
                      ),
                      CuaresmaHubNewTopicButton(onPressed: onNewTopic),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HubCountPill(
                        icon: Icons.campaign_outlined,
                        label: liveEnsayoCount > 0
                            ? (liveEnsayoCount == 1
                                ? '1 ensayo en directo'
                                : '$liveEnsayoCount ensayos en directo')
                            : (todayEnsayoCount == 1
                                ? '1 ensayo hoy'
                                : '$todayEnsayoCount ensayos hoy'),
                        live: liveEnsayoCount > 0,
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
          ),
        ),
        const SizedBox(height: 0),
      ],
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
            : AppColors.background,
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

class _CuaresmaHeroFallback extends StatelessWidget {
  const _CuaresmaHeroFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.burgundyDark,
            AppColors.burgundy,
            AppColors.burgundyDark.withValues(alpha: 0.9),
          ],
        ),
      ),
    );
  }
}
