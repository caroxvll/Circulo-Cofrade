import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../../search/follows_provider.dart';
import '../data/mock_forums.dart';
import '../utils/hermandad_board_display.dart';
import '../utils/hermandad_local_assets.dart';
import 'hermandad_board_stats_sheet.dart';
import 'topic_card.dart';
import 'topic_follow_button.dart';

/// Cabecera del canal oficial: hero a sangre con escudo, CTA y stats.
class HermandadBoardHeader extends ConsumerStatefulWidget {
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
  ConsumerState<HermandadBoardHeader> createState() =>
      _HermandadBoardHeaderState();
}

class _HermandadBoardHeaderState extends ConsumerState<HermandadBoardHeader> {
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
    final coverUrl = topic.coverImageUrl?.trim();
    final hasRemoteCover = coverUrl != null && coverUrl.isNotEmpty;
    final washAsset = HermandadLocalAssets.cardWash(
      processionDay: parsed.processionDay,
      hermandadName: parsed.hermandadName,
    );
    // Portada remota (admin) gana; si no, fondo local empaquetado.
    final hasLocalWash = !hasRemoteCover && washAsset != null;
    final followers =
        ref.watch(topicFollowerCountProvider(widget.topicId)).asData?.value ??
            0;

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
                  if (hasRemoteCover)
                    _BoardHeroCover(imageUrl: coverUrl)
                  else if (hasLocalWash)
                    _BoardHeroCover(assetPath: washAsset),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x40000000),
                          Color(0x88000000),
                          Color(0xF23D0006),
                        ],
                        stops: [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Sin Positioned: da altura al Stack (si todo es Positioned, no se ve nada).
            // Padding inferior holgado para que el pill verificado no lo tape la stats card.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 46),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CrestBadge(topic: topic),
                    const SizedBox(height: 6),
                    Text(
                      parsed.hermandadName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.hermandadName(
                        color: AppColors.textOnDark,
                      ).copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (parsed.processionDay != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '— ${parsed.processionDay!} —',
                        textAlign: TextAlign.center,
                        style: AppTypography.rankTitle(
                          color: AppColors.gold,
                        ).copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const _VerifiedPill(),
                  ],
                ),
              ),
            ),
            if (topic.isPublished)
              Positioned(
                top: 8,
                right: 10,
                child: TopicFollowButton(
                  forumId: widget.forumId,
                  topicId: widget.topicId,
                  isHermandadBoard: true,
                  overlayStyle: true,
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: -18,
              child: _StatsCard(
                displayCommentCount: widget.displayCommentCount,
                displayFollowerCount: followers,
                displayTotalReactions: widget.displayTotalReactions,
                displayViewCount: widget.displayViewCount,
                reactionBreakdown: widget.reactionBreakdown,
              ),
            ),
          ],
        ),
        SizedBox(height: customBody != null ? 26 : 24),
        if (customBody != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
            child: Text(
              customBody,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, height: 1.3),
            ),
          ),
      ],
    );
  }
}

class _CrestBadge extends StatelessWidget {
  const _CrestBadge({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PinnedTopicMark(
              topic: topic,
              size: size - 6,
              circular: true,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.burgundyDark, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: AppColors.gold),
          const SizedBox(width: 3),
          Text(
            'Canal oficial verificado',
            style: AppTypography.labelSmall(
              color: AppColors.textOnDark,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.displayCommentCount,
    required this.displayFollowerCount,
    required this.displayTotalReactions,
    required this.displayViewCount,
    required this.reactionBreakdown,
  });

  final int displayCommentCount;
  final int displayFollowerCount;
  final int displayTotalReactions;
  final int displayViewCount;
  final Map<String, int> reactionBreakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 10,
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
              label: 'Seguidores',
              value: formatCount(displayFollowerCount),
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatCell(
              label: 'Reacciones',
              value: formatCount(displayTotalReactions),
              onTap: displayTotalReactions > 0 || displayFollowerCount > 0
                  ? () => showHermandadBoardStatsSheet(
                        context,
                        viewCount: displayViewCount,
                        followerCount: displayFollowerCount,
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
            style: AppTypography.hermandadName(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.05),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall(
              color: AppColors.textMuted,
            ).copyWith(fontSize: 10, fontWeight: FontWeight.w500),
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
      height: 24,
      color: AppColors.border.withValues(alpha: 0.85),
    );
  }
}
