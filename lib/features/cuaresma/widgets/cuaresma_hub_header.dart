import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_asset_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../forums/data/topic_icon_assets.dart';
import '../../forums/topic_detail_typography.dart';
import 'cuaresma_hub_design.dart';

class CuaresmaHubHeroStack extends StatelessWidget {
  const CuaresmaHubHeroStack({
    super.key,
    required this.agendaLabel,
    required this.agendaLive,
    required this.topicsCount,
    required this.onNewTopic,
    this.imageSource,
  });

  final String? imageSource;
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
    final image = imageSource?.trim();
    final hasImage = image != null && image.isNotEmpty;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              SizedBox(
                height: 176,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CuaresmaHeaderImage(source: image),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x14000000),
                            Color(0x00000000),
                            Color(0xCC2A090C),
                          ],
                          stops: [0, 0.42, 1],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _HeaderEyebrow(onImage: true),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Hoy en Cuaresma',
                                  style: AppTypography.newsHeadline(
                                    color: AppColors.textOnDark,
                                  ).copyWith(fontSize: 26, height: 1),
                                ),
                              ),
                              CuaresmaHubNewTopicButton(onPressed: onNewTopic),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasImage) ...[
                    const _HeaderEyebrow(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
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
                  ],
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

class _HeaderEyebrow extends StatelessWidget {
  const _HeaderEyebrow({this.onImage = false});

  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final color = onImage ? AppColors.goldPale : AppColors.goldDark;
    return Row(
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'AGENDA Y COMUNIDAD',
          style: TopicDetailTypography.meta(
            color: color,
            fontWeight: FontWeight.w800,
          ).copyWith(fontSize: 9.5, letterSpacing: 1.1),
        ),
      ],
    );
  }
}

class _CuaresmaHeaderImage extends StatelessWidget {
  const _CuaresmaHeaderImage({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    if (topicCoverIsAsset(source)) {
      return CofradeoAssetImage(
        assetPath: source,
        fit: BoxFit.cover,
        cacheWidth: ImageDecodeCache.px(
          context,
          MediaQuery.sizeOf(context).width,
        ),
        cacheHeight: ImageDecodeCache.px(context, 176),
      );
    }
    return CofradeoNetworkImage(
      url: source,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 176,
      cacheSize: 900,
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

