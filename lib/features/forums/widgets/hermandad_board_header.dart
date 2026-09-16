import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../forum_topics_typography.dart';
import '../topic_detail_typography.dart';
import '../utils/hermandad_board_display.dart';
import '../utils/hermandad_local_assets.dart';
import 'hermandad_board_stats_sheet.dart';
import 'topic_card.dart';
import 'topic_follow_button.dart';

/// Cabecera del tablón oficial: hero a sangre, escala tipográfica del resto de foros.
///
/// Fondo: mismo `fondo_*` local del card (`HermandadLocalAssets`), y si no hay
/// asset, la `coverImageUrl` del tema (red o `assets/…`).
class HermandadBoardHeader extends StatefulWidget {
  const HermandadBoardHeader({
    super.key,
    required this.topic,
    required this.forumId,
    required this.topicId,
    required this.displayCommentCount,
    required this.displayViewCount,
    this.displayTotalReactions = 0,
    this.reactionBreakdown = const {},
  });

  final ForumTopic topic;
  final String forumId;
  final String topicId;
  final int displayCommentCount;
  final int displayViewCount;
  final int displayTotalReactions;
  final Map<String, int> reactionBreakdown;

  @override
  State<HermandadBoardHeader> createState() => _HermandadBoardHeaderState();
}

class _HermandadBoardHeaderState extends State<HermandadBoardHeader> {
  @override
  void initState() {
    super.initState();
    if (!HermandadLocalAssets.isReady) {
      HermandadLocalAssets.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final parsed = parseHermandadTopicTitle(topic.title);
    final customBody = hermandadBoardCustomBody(topic.body);
    final washAsset = HermandadLocalAssets.cardWash(
      processionDay: parsed.processionDay,
      hermandadName: parsed.hermandadName,
    );
    final coverUrl = topic.coverImageUrl?.trim();
    final hasLocalWash = washAsset != null;
    final hasRemoteCover =
        !hasLocalWash && coverUrl != null && coverUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.burgundyDark),
                  if (hasLocalWash)
                    _BoardHeroCover(assetPath: washAsset)
                  else if (hasRemoteCover)
                    _BoardHeroCover(imageUrl: coverUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Color(0x99000000),
                          Color(0xE64D0008),
                        ],
                        stops: [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CrestBadge(topic: topic),
                  const SizedBox(height: 6),
                  Text(
                    parsed.hermandadName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TopicDetailTypography.heroTitle(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  if (parsed.processionDay != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoldRule(),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            parsed.processionDay!,
                            textAlign: TextAlign.center,
                            style: ForumTopicsTypography.style(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _GoldRule(),
                      ],
                    ),
                  ],
                  const SizedBox(height: 5),
                  const _VerifiedPill(),
                  if (topic.isPublished) ...[
                    const SizedBox(height: 8),
                    TopicFollowButton(
                      forumId: widget.forumId,
                      topicId: widget.topicId,
                      isHermandadBoard: true,
                      heroStyle: true,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: -18,
              child: _StatsCard(
                displayCommentCount: widget.displayCommentCount,
                displayViewCount: widget.displayViewCount,
                displayTotalReactions: widget.displayTotalReactions,
                reactionBreakdown: widget.reactionBreakdown,
              ),
            ),
          ],
        ),
        SizedBox(height: customBody != null ? 26 : 22),
        if (customBody != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              customBody,
              textAlign: TextAlign.center,
              style: TopicDetailTypography.meta(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _GoldRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 1,
      color: AppColors.gold.withValues(alpha: 0.7),
    );
  }
}

class _CrestBadge extends StatelessWidget {
  const _CrestBadge({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PinnedTopicMark(
              topic: topic,
              size: 38,
              circular: true,
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.burgundyDark, width: 1.2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 9,
                color: AppColors.burgundyDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardHeroCover extends StatelessWidget {
  const _BoardHeroCover({this.assetPath, this.imageUrl})
      : assert(assetPath != null || imageUrl != null);

  final String? assetPath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final asset = assetPath?.trim();
    if (asset != null && asset.isNotEmpty) {
      final cacheW = ImageDecodeCache.px(
        context,
        MediaQuery.sizeOf(context).width,
      );
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheW,
        gaplessPlayback: true,
      );
    }

    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (url.startsWith('assets/')) {
      final cacheW = ImageDecodeCache.px(
        context,
        MediaQuery.sizeOf(context).width,
      );
      return Image.asset(
        url,
        fit: BoxFit.cover,
        cacheWidth: cacheW,
        gaplessPlayback: true,
      );
    }
    return CofradeoNetworkImage(
      url: url,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            'Tablón oficial verificado',
            style: ForumTopicsTypography.style(
              color: AppColors.goldPale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.displayCommentCount,
    required this.displayViewCount,
    required this.displayTotalReactions,
    required this.reactionBreakdown,
  });

  final int displayCommentCount;
  final int displayViewCount;
  final int displayTotalReactions;
  final Map<String, int> reactionBreakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: 'Comunicados',
              value: '$displayCommentCount',
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatCell(
              label: 'Vistas',
              value: formatCount(displayViewCount),
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatCell(
              label: 'Reacciones',
              value: '$displayTotalReactions',
              onTap: displayTotalReactions > 0
                  ? () => showHermandadBoardStatsSheet(
                        context,
                        viewCount: displayViewCount,
                        comunicadoCount: displayCommentCount,
                        reactionBreakdown: reactionBreakdown,
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TopicDetailTypography.title().copyWith(
              fontSize: TopicDetailTypography.titleSize,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ForumTopicsTypography.style(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: AppColors.border,
    );
  }
}
