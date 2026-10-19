import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../data/forum_pillar_covers.dart';
import '../utils/forum_activity_badge.dart';
import '../utils/forum_navigation.dart';
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
    final hasHotTopic = !locked &&
        (forum.lastTopicTitle?.trim().isNotEmpty ?? false) &&
        (forum.lastTopicId?.trim().isNotEmpty ?? false);

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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: metrics.metaGap + 2),
          if (locked && forum.lockedLabel != null)
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  forum.lockedLabel!,
                  style: AppTypography.labelSmall(
                    color: AppColors.burgundy,
                  ).copyWith(
                    fontSize: metrics.metaSize,
                    fontWeight: FontWeight.w600,
                    height: 1.12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else if (hasHotTopic)
            Expanded(
              child: _ForumHotTopicStrip(
                forum: forum,
                metaSize: metrics.metaSize,
                fillHeight: true,
              ),
            )
          else
            Expanded(
              child: _ForumIdleActivityPanel(
                forum: forum,
                metaSize: metrics.metaSize,
                iconSize: metrics.iconSize,
                topicsLabel: featured ? 'noticias' : 'temas',
              ),
            ),
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

/// Hilo con actividad más reciente; [fillHeight] ocupa el hueco de la card.
class _ForumHotTopicStrip extends StatelessWidget {
  const _ForumHotTopicStrip({
    required this.forum,
    required this.metaSize,
    this.fillHeight = false,
  });

  final ForumCategory forum;
  final double metaSize;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final title = forum.lastTopicTitle!.trim();
    final topicId = forum.lastTopicId!.trim();
    final ago = forum.lastMessageAgo == 'sin actividad'
        ? null
        : forum.lastMessageAgo;
    final excerpt = (forum.lastTopicExcerpt?.trim().isNotEmpty ?? false)
        ? forum.lastTopicExcerpt!.trim()
        : 'Toca para abrir el hilo y unirte al debate.';

    return Material(
      color: AppColors.burgundyDark,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => context.push(forumTopicLocation(forum.id, topicId)),
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.gold.withValues(alpha: 0.12),
        highlightColor: AppColors.gold.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
          child: fillHeight
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildAdaptiveBody(
                      title: title,
                      ago: ago,
                      excerpt: excerpt,
                      maxHeight: constraints.maxHeight,
                    );
                  },
                )
              : _buildCompactBody(title: title, ago: ago),
        ),
      ),
    );
  }

  Widget _buildCompactBody({
    required String title,
    required String? ago,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ahoraHeader(ago),
        const SizedBox(height: 3),
        Text(
          title,
          style: _titleStyle(fillHeight: false),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Calcula líneas enteras del extracto según la altura real (evita
  /// que la última línea se pinte a medias y quede cortada).
  Widget _buildAdaptiveBody({
    required String title,
    required String? ago,
    required String excerpt,
    required double maxHeight,
  }) {
    const gapAfterHeader = 4.0;
    const gapAfterTitle = 3.0;
    const gapBeforeCta = 3.0;
    const heightSafety = 1.5;

    final headerH = metaSize + 2.5;
    final titleFontSize = metaSize + 2;
    final titleLineH = titleFontSize * 1.18;
    final excerptFontSize = metaSize + 0.5;
    final excerptLineH = excerptFontSize * 1.22;
    final ctaH = metaSize;

    var budget = maxHeight - headerH - gapAfterHeader - heightSafety;

    // Título: 2 líneas si cabe; si no, 1.
    final titleMaxLines = budget >= titleLineH * 2 + gapAfterTitle ? 2 : 1;
    budget -= titleLineH * titleMaxLines + gapAfterTitle;

    // CTA solo si queda hueco para ≥1 línea de extracto + enlace.
    final canShowCta = budget >= excerptLineH + gapBeforeCta + ctaH;
    if (canShowCta) {
      budget -= gapBeforeCta + ctaH;
    }

    final excerptMaxLines =
        (budget / excerptLineH).floor().clamp(0, 3);

    return SizedBox(
      height: maxHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ahoraHeader(ago),
          const SizedBox(height: gapAfterHeader),
          Text(
            title,
            style: _titleStyle(fillHeight: true),
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
          if (excerptMaxLines > 0) ...[
            const SizedBox(height: gapAfterTitle),
            SizedBox(
              height: excerptMaxLines * excerptLineH,
              child: Text(
                excerpt,
                style: AppTypography.bodyMedium(
                  color: AppColors.goldPale.withValues(alpha: 0.88),
                ).copyWith(
                  fontSize: excerptFontSize,
                  fontWeight: FontWeight.w400,
                  height: 1.22,
                ),
                maxLines: excerptMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (canShowCta) ...[
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Abrir hilo ›',
                style: AppTypography.labelSmall(
                  color: AppColors.gold,
                ).copyWith(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ahoraHeader(String? ago) {
    return Row(
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          size: metaSize + 2.5,
          color: AppColors.gold,
        ),
        const SizedBox(width: 4),
        Text(
          'AHORA',
          style: AppTypography.labelSmall(
            color: AppColors.gold,
          ).copyWith(
            fontSize: metaSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            height: 1,
          ),
        ),
        if (ago != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              ago,
              style: AppTypography.labelSmall(
                color: AppColors.goldPale.withValues(alpha: 0.75),
              ).copyWith(fontSize: metaSize - 0.5, height: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ],
    );
  }

  TextStyle _titleStyle({required bool fillHeight}) {
    return AppTypography.bodyMedium(
      color: AppColors.textOnDark,
    ).copyWith(
      fontSize: metaSize + (fillHeight ? 2 : 1.5),
      fontWeight: FontWeight.w700,
      height: 1.18,
    );
  }
}

/// Panel cuando aún no hay hilo caliente: rellena el hueco con stats.
class _ForumIdleActivityPanel extends StatelessWidget {
  const _ForumIdleActivityPanel({
    required this.forum,
    required this.metaSize,
    required this.iconSize,
    required this.topicsLabel,
  });

  final ForumCategory forum;
  final double metaSize;
  final double iconSize;
  final String topicsLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sin actividad reciente',
              style: AppTypography.labelSmall(
                color: AppColors.burgundy,
              ).copyWith(
                fontSize: metaSize + 0.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const Spacer(),
            _ForumCardStatsRow(
              forum: forum,
              metaSize: metaSize,
              iconSize: iconSize,
              topicsLabel: topicsLabel,
            ),
            const SizedBox(height: 4),
            Text(
              'Sé el primero en abrir un tema',
              style: AppTypography.labelSmall(
                color: AppColors.textMuted,
              ).copyWith(fontSize: metaSize, height: 1.15),
            ),
          ],
        ),
      ),
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
  return '$value';
}
