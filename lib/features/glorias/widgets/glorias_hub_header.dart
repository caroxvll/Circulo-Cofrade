import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../../cuaresma/widgets/cuaresma_hub_design.dart';
import '../../forums/data/topic_icon_assets.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/widgets/topic_card.dart';

class GloriasHubHeroStack extends StatelessWidget {
  const GloriasHubHeroStack({
    super.key,
    required this.topic,
    required this.upcomingCount,
    required this.topicsCount,
    required this.onNewTopic,
  });

  final ForumTopic topic;
  final int upcomingCount;
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
                    ? Image.asset(
                        cover,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: ImageDecodeCache.px(
                          context,
                          MediaQuery.sizeOf(context).width,
                        ),
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const _GloriasHeroFallback(),
                      )
                    : CofradeoNetworkImage(
                        url: cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: _heroHeight,
                        cacheSize: 720,
                        filterQuality: FilterQuality.medium,
                        errorWidget: const _GloriasHeroFallback(),
                      )
              else
                const _GloriasHeroFallback(),
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
                              'Festividades y vida cofrade',
                              style: TopicDetailTypography.meta(
                                color: AppColors.textOnDark.withValues(
                                  alpha: 0.88,
                                ),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temporada de Glorias',
                          style: TopicDetailTypography.body(
                            color: AppColors.burgundy,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            CuaresmaHubStatChip(
                              icon: Icons.event_outlined,
                              label: upcomingCount == 1
                                  ? '1 gloria próxima'
                                  : '$upcomingCount glorias próximas',
                              highlighted: upcomingCount > 0,
                            ),
                            CuaresmaHubStatChip(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: topicsCount == 1
                                  ? '1 tema abierto'
                                  : '$topicsCount temas abiertos',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CuaresmaHubNewTopicButton(onPressed: onNewTopic),
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

class _GloriasHeroFallback extends StatelessWidget {
  const _GloriasHeroFallback();

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
            AppColors.gold.withValues(alpha: 0.55),
          ],
        ),
      ),
    );
  }
}
