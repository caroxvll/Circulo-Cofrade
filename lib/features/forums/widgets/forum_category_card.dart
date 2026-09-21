import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../data/forum_pillar_covers.dart';
import '../data/mock_forums.dart';
import '../utils/forum_activity_badge.dart';
import 'forum_last_activity_link.dart';
import 'forum_pillar_icon_mark.dart';

class ForumCategoryCard extends StatelessWidget {
  const ForumCategoryCard({
    super.key,
    required this.forum,
    required this.onTap,
    this.height = cardHeight,
    this.featured = false,
  });

  final ForumCategory forum;
  final VoidCallback onTap;
  final double height;
  final bool featured;

  static const cardHeight = 128.0;
  static const featuredHeight = 136.0;
  static const cardGap = 5.0;
  static const cardRadius = 16.0;

  /// Ancho de la miniatura: prioriza fracción del ancho de tarjeta (foto grande).
  static double coverWidthFor({
    required double height,
    required double cardWidth,
    required bool compact,
    bool featured = false,
  }) {
    final widthShare = cardWidth * (featured ? 0.34 : (compact ? 0.26 : 0.28));
    final heightCap = height * (compact ? 0.90 : 0.96);
    return math.max(height * 0.72, math.min(widthShare, heightCap));
  }

  @override
  Widget build(BuildContext context) {
    final locked = forum.isLocked;
    final activity = forumActivityLevel(forum);
    final compact = height < 100;

    return Opacity(
      opacity: locked ? 0.82 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(cardRadius),
        elevation: 0,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(cardRadius),
          splashColor: AppColors.burgundy.withValues(alpha: 0.06),
          highlightColor: AppColors.gold.withValues(alpha: 0.04),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: AppColors.gold.withValues(
                  alpha: featured ? 0.28 : 0.16,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.07),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final thumbWidth = coverWidthFor(
                  height: height,
                  cardWidth: constraints.maxWidth,
                  compact: compact,
                  featured: featured,
                );
                final iconMarkSize =
                    (height * (compact ? 0.38 : 0.42)).clamp(32.0, 46.0);

                return SizedBox(
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ForumCoverThumb(
                        forum: forum,
                        locked: locked,
                        width: thumbWidth,
                        height: height,
                        iconMarkSize: iconMarkSize,
                      ),
                      Expanded(
                        child: _ForumCardContent(
                          forum: forum,
                          locked: locked,
                          activity: activity,
                          height: height,
                          featured: featured,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ForumCardContent extends StatelessWidget {
  const _ForumCardContent({
    required this.forum,
    required this.locked,
    required this.activity,
    required this.height,
    this.featured = false,
  });

  final ForumCategory forum;
  final bool locked;
  final ForumActivityLevel activity;
  final double height;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final metrics = _CardContentMetrics.forHeight(height, featured: featured);
    final descriptionLines = height >= 118 ? 2 : 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.horizontalPad,
        metrics.verticalPad,
        metrics.horizontalPad,
        metrics.verticalPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  forum.name,
                  style: _titleStyle(locked, metrics.titleSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _ActivityBadge(level: activity, compact: true),
              if (!locked) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.burgundyDark,
                  size: metrics.titleSize + 2,
                ),
              ] else
                Icon(
                  Icons.lock_outline,
                  color: AppColors.textMuted,
                  size: metrics.titleSize + 1,
                ),
            ],
          ),
          SizedBox(height: metrics.gap),
          Text(
            forum.description,
            style: AppTypography.bodyMedium(
              color: locked
                  ? AppColors.textMuted
                  : AppColors.textSecondary,
            ).copyWith(
              fontSize: metrics.bodySize,
              height: metrics.bodyLineHeight,
            ),
            maxLines: descriptionLines,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (locked && forum.lockedLabel != null)
            Text(
              forum.lockedLabel!,
              style: AppTypography.labelSmall(
                color: AppColors.burgundy,
              ).copyWith(
                fontSize: metrics.metaSize,
                fontWeight: FontWeight.w600,
                height: 1.12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else ...[
            _ForumCardStatsRow(
              forum: forum,
              metaSize: metrics.metaSize,
              iconSize: metrics.iconSize,
              topicsLabel: featured ? 'noticias' : 'temas',
            ),
            SizedBox(height: metrics.metaGap),
            ForumLastActivityLink(
              forum: forum,
              compact: true,
              accentColor: AppColors.burgundy,
              fontSize: metrics.metaSize,
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _titleStyle(bool locked, double titleSize) {
    return AppTypography.displaySmall(
      color: locked ? AppColors.textMuted : AppColors.burgundyDark,
    ).copyWith(
      fontSize: titleSize,
      fontWeight: FontWeight.w600,
      height: 1.1,
      letterSpacing: 0.02,
    );
  }
}

class _CardContentMetrics {
  const _CardContentMetrics({
    required this.verticalPad,
    required this.horizontalPad,
    required this.titleSize,
    required this.bodySize,
    required this.bodyLineHeight,
    required this.metaSize,
    required this.iconSize,
    required this.gap,
    required this.metaGap,
  });

  final double verticalPad;
  final double horizontalPad;
  final double titleSize;
  final double bodySize;
  final double bodyLineHeight;
  final double metaSize;
  final double iconSize;
  final double gap;
  final double metaGap;

  static _CardContentMetrics forHeight(
    double height, {
    bool featured = false,
  }) {
    if (featured || height >= 120) {
      return const _CardContentMetrics(
        verticalPad: 9,
        horizontalPad: 10,
        titleSize: 14.5,
        bodySize: 11.5,
        bodyLineHeight: 1.22,
        metaSize: 9.5,
        iconSize: 11,
        gap: 4,
        metaGap: 3,
      );
    }
    if (height >= 108) {
      return const _CardContentMetrics(
        verticalPad: 8,
        horizontalPad: 10,
        titleSize: 14,
        bodySize: 11,
        bodyLineHeight: 1.2,
        metaSize: 9,
        iconSize: 10.5,
        gap: 3,
        metaGap: 2,
      );
    }
    return const _CardContentMetrics(
      verticalPad: 7,
      horizontalPad: 9,
      titleSize: 13.5,
      bodySize: 10.5,
      bodyLineHeight: 1.18,
      metaSize: 8.6,
      iconSize: 10.5,
      gap: 3,
      metaGap: 2,
    );
  }
}

class _ForumCardStatsRow extends StatelessWidget {
  const _ForumCardStatsRow({
    required this.forum,
    required this.metaSize,
    required this.iconSize,
    this.topicsLabel = 'temas',
  });

  final ForumCategory forum;
  final double metaSize;
  final double iconSize;
  final String topicsLabel;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.labelSmall(
      color: AppColors.textMuted,
    ).copyWith(fontSize: metaSize, height: 1.1);

    return Row(
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: iconSize,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text('${_shortCount(forum.messageCount)} mensajes', style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: 1,
            height: iconSize - 1,
            color: AppColors.border.withValues(alpha: 0.65),
          ),
        ),
        Icon(
          Icons.folder_outlined,
          size: iconSize,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${_shortCount(forum.topicCount)} $topicsLabel',
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ForumCoverThumb extends StatelessWidget {
  const _ForumCoverThumb({
    required this.forum,
    required this.locked,
    required this.width,
    required this.height,
    required this.iconMarkSize,
  });

  final ForumCategory forum;
  final bool locked;
  final double width;
  final double height;
  final double iconMarkSize;

  @override
  Widget build(BuildContext context) {
    final cover = forumPillarCover(forum);
    const radius = BorderRadius.horizontal(
      left: Radius.circular(ForumCategoryCard.cardRadius),
    );
    final iconOffset = iconMarkSize * 0.34;
    final light = cover.lightTreatment;
    final overlayAlpha = light ? 0.0 : 0.28;
    final vignetteVertical = light ? 0.06 : 0.18;
    final edgeFade = light ? 0.08 : 0.35;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: radius,
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ForumPillarCoverImage(
                    cover: cover,
                    fit: BoxFit.cover,
                    alignment: cover.alignment,
                    filterQuality: FilterQuality.medium,
                    width: width,
                    height: height,
                    cacheSize: math.max(width, height),
                    color: locked ? Colors.grey : null,
                    colorBlendMode: locked ? BlendMode.saturation : null,
                  ),
                  if (cover.overlay != AppColorsOverlay.none && overlayAlpha > 0)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: cover.overlay.withValues(alpha: overlayAlpha),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: vignetteVertical),
                          Colors.transparent,
                          Colors.black.withValues(alpha: vignetteVertical * 0.65),
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: vignetteVertical * 0.45),
                          Colors.transparent,
                          AppColors.surfaceAlt.withValues(alpha: edgeFade),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!locked)
            Positioned(
              right: -iconOffset,
              bottom: height * 0.08,
              child: _MedallionIconMark(
                forum: forum,
                size: iconMarkSize,
              ),
            ),
        ],
      ),
    );
  }
}

class _MedallionIconMark extends StatelessWidget {
  const _MedallionIconMark({required this.forum, required this.size});

  final ForumCategory forum;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceAlt, width: 2.5),
        ),
        child: ForumPillarIconMark(forum: forum, size: size),
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.level, this.compact = false});

  final ForumActivityLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (border, fg, dot) = switch (level) {
      ForumActivityLevel.veryActive => (
        AppColors.gold.withValues(alpha: 0.45),
        AppColors.goldDark,
        AppColors.gold,
      ),
      ForumActivityLevel.active => (
        AppColors.burgundy.withValues(alpha: 0.22),
        AppColors.burgundyDark,
        AppColors.burgundy,
      ),
      ForumActivityLevel.low => (
        AppColors.border.withValues(alpha: 0.7),
        AppColors.textMuted,
        AppColors.textMuted,
      ),
      ForumActivityLevel.upcoming => (
        AppColors.burgundy.withValues(alpha: 0.25),
        AppColors.burgundy,
        null,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            forumActivityLabel(level),
            style: AppTypography.labelSmall(color: fg).copyWith(
              fontSize: compact ? 7.8 : 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortCount(int value) {
  if (value >= 1000) {
    final short = value / 1000;
    return '${short.toStringAsFixed(short >= 10 ? 0 : 1)}k';
  }
  return formatCount(value);
}
