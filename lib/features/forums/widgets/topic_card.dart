import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../../shared/models/forum.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../search/follows_provider.dart';
import '../forum_topics_typography.dart';
import '../data/topic_icon_assets.dart';
import '../data/mock_forums.dart';
import '../utils/hermandad_board_display.dart';
import '../utils/hermandad_local_assets.dart';
import '../utils/topic_list_order.dart';
import 'related_forum_chip.dart';
import 'topic_status_badge.dart';

enum TopicCardVariant { standard, premium, noticias }

class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.topic,
    required this.onTap,
    this.pinned = false,
    this.variant = TopicCardVariant.standard,
    this.forumId,
  });

  final ForumTopic topic;
  final VoidCallback onTap;
  final bool pinned;
  final TopicCardVariant variant;
  final String? forumId;

  @override
  Widget build(BuildContext context) {
    if (variant == TopicCardVariant.noticias) {
      return _NoticiasTopicCard(
        topic: topic,
        onTap: onTap,
        featured: pinned,
      );
    }

    if (variant == TopicCardVariant.premium) {
      return _PremiumTopicCard(
        topic: topic,
        onTap: onTap,
        pinned: pinned,
      );
    }

    return _StandardTopicCard(
      topic: topic,
      onTap: onTap,
      pinned: pinned,
    );
  }
}

class _StandardTopicCard extends StatelessWidget {
  const _StandardTopicCard({
    required this.topic,
    required this.onTap,
    required this.pinned,
  });

  final ForumTopic topic;
  final VoidCallback onTap;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final displayTitle = _displayTitle(topic.title);

    return Material(
      color: pinned ? AppColors.backgroundElevated : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pinned ? AppColors.goldDark : AppColors.border,
              width: pinned ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pinned
                  ? PinnedTopicMark(topic: topic)
                  : CofradeoAvatar(
                      imageUrl: topic.authorAvatarUrl,
                      icon: topic.avatarIcon,
                      size: 44,
                      backgroundColor: AppColors.backgroundElevated,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (pinned) ...[
                                Icon(
                                  Icons.push_pin,
                                  size: 14,
                                  color: AppColors.goldDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Destacado',
                                  style: AppTypography.labelSmall(
                                    color: AppColors.goldDark,
                                  ),
                                ),
                              ] else ...[
                                Flexible(
                                  child: Text(
                                    topic.authorHandle,
                                    style: AppTypography.bodyMedium(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (topic.authorVerified) ...[
                                  const SizedBox(width: 4),
                                  const VerifiedAccountIcon(size: 15),
                                ],
                              ],
                            ],
                          ),
                        ),
                        if (!pinned)
                          Text(
                            topic.timeAgo,
                            style: AppTypography.labelSmall(
                              color: AppColors.accentRed,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayTitle,
                      style: AppTypography.displaySmall(
                        color: AppColors.textPrimary,
                      ).copyWith(fontSize: 17),
                    ),
                    if (topic.relatedForumId != null) ...[
                      const SizedBox(height: 8),
                      RelatedForumChip(
                        relatedForumId: topic.relatedForumId!,
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      topic.excerpt,
                      style: AppTypography.bodyMedium(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${topic.commentCount}',
                          style: AppTypography.labelSmall(),
                        ),
                        const SizedBox(width: 14),
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${formatCount(topic.viewCount)} vistas',
                          style: AppTypography.labelSmall(),
                        ),
                        const Spacer(),
                        TopicStatusBadge(topic: topic),
                      ],
                    ),
                  ],
                ),
              ),
              if (_topicListCoverUrl(topic) != null) ...[
                const SizedBox(width: 10),
                _TopicListCoverThumb(url: _topicListCoverUrl(topic)!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumTopicCard extends StatelessWidget {
  const _PremiumTopicCard({
    required this.topic,
    required this.onTap,
    required this.pinned,
  });

  static const cardRadius = 14.0;

  final ForumTopic topic;
  final VoidCallback onTap;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final parsed = parseHermandadTopicTitle(topic.title);
    final name = parsed.hermandadName;
    final day = parsed.processionDay;
    final accent = hermandadDayAccentColor(day);
    final excerpt = topic.excerpt.trim();
    final isNew = isTopicNew(topic);
    final washAsset = HermandadLocalAssets.cardWash(
      processionDay: day,
      hermandadName: name,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        splashColor: AppColors.burgundy.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            color: AppColors.surface,
            border: Border.all(
              color: pinned
                  ? AppColors.goldDark.withValues(alpha: 0.42)
                  : AppColors.gold.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundyDark.withValues(
                  alpha: pinned ? 0.09 : 0.06,
                ),
                blurRadius: pinned ? 18 : 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: IntrinsicHeight(
              child: Stack(
                children: [
                  if (washAsset != null)
                    Positioned.fill(
                      child: _HermandadCardWash(assetPath: washAsset),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        color: pinned ? AppColors.burgundy : accent,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PinnedTopicMark(
                                topic: topic,
                                size: pinned ? 52 : 44,
                                circular: !pinned,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: AppTypography.displaySmall(
                                              color: AppColors.textPrimary,
                                            ).copyWith(
                                              fontSize: 16,
                                              height: 1.15,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.15,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          topic.timeAgo,
                                          style: ForumTopicsTypography.card(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (day != null ||
                                        pinned ||
                                        isNew ||
                                        topic.relatedForumId != null) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (topic.relatedForumId != null)
                                            RelatedForumChip(
                                              relatedForumId:
                                                  topic.relatedForumId!,
                                              compact: true,
                                            ),
                                          if (day != null)
                                            _HermandadMetaPill(
                                              label: day,
                                              foreground: accent,
                                              background: accent.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                          if (pinned)
                                            const _HermandadMetaPill(
                                              label: 'Destacado',
                                              foreground: AppColors.goldDark,
                                              background: AppColors.goldPale,
                                              icon: Icons.push_pin,
                                            ),
                                          if (isNew)
                                            _HermandadMetaPill(
                                              label: 'Nuevo',
                                              foreground: AppColors.burgundy,
                                              background: AppColors.burgundy
                                                  .withValues(alpha: 0.1),
                                            ),
                                        ],
                                      ),
                                    ],
                                    if (excerpt.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        excerpt,
                                        style: ForumTopicsTypography.card(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    _PremiumTopicStatsRow(topic: topic),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.7),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTopicStatsRow extends StatelessWidget {
  const _PremiumTopicStatsRow({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final style = ForumTopicsTypography.card(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 12,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text('${topic.commentCount}', style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Container(
            width: 1,
            height: 10,
            color: AppColors.border.withValues(alpha: 0.65),
          ),
        ),
        Icon(
          Icons.visibility_outlined,
          size: 12,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text(
          '${formatCount(topic.viewCount)} vistas',
          style: style,
        ),
      ],
    );
  }
}

/// Card editorial del foro Noticias (destacada o compacta).
class _NoticiasTopicCard extends StatelessWidget {
  const _NoticiasTopicCard({
    required this.topic,
    required this.onTap,
    required this.featured,
  });

  static const cardRadius = 14.0;

  final ForumTopic topic;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        splashColor: AppColors.burgundy.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            color: AppColors.surface,
            border: Border.all(
              color: featured
                  ? AppColors.goldDark.withValues(alpha: 0.38)
                  : AppColors.gold.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundyDark.withValues(
                  alpha: featured ? 0.1 : 0.06,
                ),
                blurRadius: featured ? 18 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: featured
                ? _NoticiasFeaturedBody(topic: topic)
                : _NoticiasCompactBody(topic: topic),
          ),
        ),
      ),
    );
  }
}

class _NoticiasFeaturedBody extends StatelessWidget {
  const _NoticiasFeaturedBody({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoticiasCoverImage(
          topic: topic,
          width: 112,
          square: true,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _DestacadaBadge(),
                    const Spacer(),
                    Text(
                      topic.timeAgo,
                      style: ForumTopicsTypography.card(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted.withValues(alpha: 0.75),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  topic.title,
                  style: AppTypography.displaySmall(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 18, height: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  topic.excerpt,
                  style: ForumTopicsTypography.card(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ).copyWith(fontSize: 12, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _NoticiasStatsRow(topic: topic),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticiasCompactBody extends StatelessWidget {
  const _NoticiasCompactBody({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticiasCoverImage(
            topic: topic,
            width: 86,
            height: 64,
            square: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        topic.title,
                        style: AppTypography.displaySmall(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 16, height: 1.15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted.withValues(alpha: 0.75),
                    ),
                  ],
                ),
                if (topic.relatedForumId != null) ...[
                  const SizedBox(height: 6),
                  RelatedForumChip(
                    relatedForumId: topic.relatedForumId!,
                    compact: true,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      topic.timeAgo,
                      style: ForumTopicsTypography.card(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (topic.excerpt.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    topic.excerpt,
                    style: ForumTopicsTypography.card(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ).copyWith(fontSize: 12, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                _NoticiasStatsRow(topic: topic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestacadaBadge extends StatelessWidget {
  const _DestacadaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: AppColors.goldDark),
          const SizedBox(width: 3),
          Text(
            'Destacada',
            style: ForumTopicsTypography.card(
              color: AppColors.goldDark,
              fontWeight: FontWeight.w700,
            ).copyWith(fontSize: 10, height: 1),
          ),
        ],
      ),
    );
  }
}

class _NoticiasStatsRow extends StatelessWidget {
  const _NoticiasStatsRow({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final style = ForumTopicsTypography.card(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text('${formatCount(topic.viewCount)}', style: style),
        const SizedBox(width: 10),
        Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text('${topic.commentCount}', style: style),
      ],
    );
  }
}

class _NoticiasCoverImage extends StatelessWidget {
  const _NoticiasCoverImage({
    required this.topic,
    required this.width,
    this.height,
    required this.square,
  });

  final ForumTopic topic;
  final double width;
  final double? height;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final cover = topicCoverImageSource(topic);
    final icon = topicDisplayIcon(topic);
    final resolvedHeight = square ? width : (height ?? width * 0.75);

    Widget placeholder() => ColoredBox(
      color: AppColors.burgundy.withValues(alpha: 0.92),
      child: Center(
        child: Icon(icon, color: AppColors.gold, size: width * 0.28),
      ),
    );

    Widget buildImage({required double? imageHeight}) {
      if (cover == null) return placeholder();
      if (topicCoverIsAsset(cover)) {
        return Image.asset(
          cover,
          fit: BoxFit.cover,
          width: width,
          height: imageHeight,
          filterQuality: FilterQuality.low,
          cacheWidth: ImageDecodeCache.px(context, width),
          cacheHeight: ImageDecodeCache.px(
            context,
            imageHeight ?? resolvedHeight,
          ),
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => placeholder(),
        );
      }
      return CofradeoNetworkImage(
        url: cover,
        fit: BoxFit.cover,
        width: width,
        height: imageHeight,
        cacheSize: width,
        errorWidget: placeholder(),
      );
    }

    if (square) {
      return SizedBox(
        width: width,
        height: width,
        child: buildImage(imageHeight: width),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: resolvedHeight,
        child: buildImage(imageHeight: resolvedHeight),
      ),
    );
  }
}

/// Foto de hermandad suave: se ve a la izquierda y se funde a blanco.
/// Sin Opacity/ShaderMask (capas offscreen caras en listas).
class _HermandadCardWash extends StatelessWidget {
  const _HermandadCardWash({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final cacheW = ImageDecodeCache.px(
      context,
      MediaQuery.sizeOf(context).width * 0.55,
    );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: const Alignment(-0.4, 0),
            filterQuality: FilterQuality.low,
            cacheWidth: cacheW,
            gaplessPlayback: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x66FFFFFF),
                  Color(0xBBFFFFFF),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.48, 0.82],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HermandadMetaPill extends StatelessWidget {
  const _HermandadMetaPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: ForumTopicsTypography.card(
              color: foreground,
              fontWeight: FontWeight.w600,
            ).copyWith(fontSize: 10, letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}

class _PinnedTopicLabel extends StatelessWidget {
  const _PinnedTopicLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.push_pin,
          size: 9,
          color: AppColors.goldDark.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 2),
        Text(
          'DESTACADO',
          style: ForumTopicsTypography.card(
            color: AppColors.goldDark,
            fontWeight: FontWeight.w700,
          ),
          textHeightBehavior:
              ForumTopicsTypography.compactTextHeightBehavior,
        ),
      ],
    );
  }
}

class _TopicCardMetaRow extends StatelessWidget {
  const _TopicCardMetaRow({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final metaStyle = ForumTopicsTypography.card(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 11,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text('${topic.commentCount}', style: metaStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: 1,
            height: 9,
            color: AppColors.border.withValues(alpha: 0.65),
          ),
        ),
        Icon(
          Icons.visibility_outlined,
          size: 11,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${formatCount(topic.viewCount)} vistas',
            style: metaStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: 1,
            height: 9,
            color: AppColors.border.withValues(alpha: 0.65),
          ),
        ),
        Icon(
          Icons.schedule_outlined,
          size: 11,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            topic.timeAgo,
            style: ForumTopicsTypography.card(
              color: AppColors.accentRed,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textHeightBehavior:
                ForumTopicsTypography.compactTextHeightBehavior,
          ),
        ),
        if (topic.listStatusBadge != null) ...[
          const Spacer(),
          TopicStatusBadge(topic: topic),
        ],
      ],
    );
  }
}

class _TopicListLeading extends StatelessWidget {
  const _TopicListLeading({
    required this.topic,
    required this.pinned,
    required this.size,
    required this.showNewBadge,
    this.compact = false,
    this.showPinBadge = true,
  });

  final ForumTopic topic;
  final bool pinned;
  final double size;
  final bool showNewBadge;
  final bool compact;
  final bool showPinBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (pinned)
          PinnedTopicMark(topic: topic, size: size, circular: true)
        else
          CofradeoAvatar(
            imageUrl: topic.authorAvatarUrl,
            icon: topic.avatarIcon,
            size: size,
            backgroundColor: AppColors.backgroundElevated,
          ),
        if (showNewBadge)
          Positioned(
            top: compact ? -4 : -5,
            right: compact ? -4 : -6,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 6,
                vertical: compact ? 1 : 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'Nuevo',
                style: ForumTopicsTypography.card(
                  color: AppColors.burgundyDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (pinned && showPinBadge)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: compact ? 14 : 18,
              height: compact ? 14 : 18,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface,
                  width: compact ? 1 : 1.5,
                ),
              ),
              child: Icon(
                Icons.push_pin,
                size: compact ? 8 : 10,
                color: AppColors.burgundyDark,
              ),
            ),
          ),
      ],
    );
  }
}

class TopicCardFollowMark extends ConsumerWidget {
  const TopicCardFollowMark({
    super.key,
    required this.forumId,
    required this.topicId,
    this.compact = false,
  });

  final String forumId;
  final String topicId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconSize = compact ? 14.0 : 18.0;
    final supabaseReady = ref.watch(supabaseReadyProvider);
    if (!supabaseReady) {
      return Icon(
        Icons.bookmark_border,
        size: iconSize,
        color: AppColors.textMuted.withValues(alpha: 0.7),
      );
    }

    final followingAsync = ref.watch(isFollowingTopicProvider(topicId));

    return followingAsync.when(
      loading: () => SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.textMuted.withValues(alpha: 0.5),
        ),
      ),
      error: (_, _) => Icon(
        Icons.bookmark_border,
        size: iconSize,
        color: AppColors.textMuted.withValues(alpha: 0.7),
      ),
      data: (isFollowing) => IconButton(
        onPressed: () => _toggleFollow(context, ref, isFollowing),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: compact ? 22 : 28,
          minHeight: compact ? 22 : 28,
        ),
        visualDensity: VisualDensity.compact,
        icon: Icon(
          isFollowing ? Icons.bookmark : Icons.bookmark_border,
          size: compact ? 13 : 16,
          color: isFollowing ? AppColors.burgundy : AppColors.textMuted,
        ),
      ),
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    bool isFollowing,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await context.push(
        '/login?redirect=${Uri.encodeComponent('/foros/$forumId/tema/$topicId')}',
      );
      return;
    }

    if (!await ensureEmailVerifiedForEngage(context, ref)) return;

    try {
      await ref.read(topicFollowControllerProvider).toggle(
            topicId: topicId,
            currentlyFollowing: isFollowing,
          );
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/foros/$forumId/tema/$topicId')}',
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el tema.'),
          ),
        );
      }
    }
  }
}

class PinnedTopicMark extends StatelessWidget {
  const PinnedTopicMark({
    super.key,
    required this.topic,
    this.size = 44,
    this.circular = false,
  });

  final ForumTopic topic;
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final parsed = parseHermandadTopicTitle(topic.title);
    final localEscudo = HermandadLocalAssets.avatar(
      processionDay: parsed.processionDay,
      hermandadName: parsed.hermandadName,
    );
    final cover = localEscudo ?? topicCoverImageSource(topic);
    final icon = topicDisplayIcon(topic);
    final radius = size >= 48 ? 14.0 : 12.0;
    final isLocalEscudo = localEscudo != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLocalEscudo ? AppColors.surface : AppColors.burgundy,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(radius),
        border: Border.all(
          color: isLocalEscudo
              ? AppColors.gold.withValues(alpha: 0.55)
              : AppColors.goldDark.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: cover == null
          ? Icon(icon, color: AppColors.gold, size: size * 0.5)
          : topicCoverIsAsset(cover) || isLocalEscudo
          ? Image.asset(
              cover,
              fit: isLocalEscudo ? BoxFit.contain : BoxFit.cover,
              filterQuality: FilterQuality.low,
              cacheWidth: ImageDecodeCache.px(context, size),
              cacheHeight: ImageDecodeCache.px(context, size),
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  Icon(icon, color: AppColors.gold, size: size * 0.5),
            )
          : CofradeoNetworkImage(
              url: cover,
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheSize: size,
              errorWidget: Icon(icon, color: AppColors.gold, size: size * 0.5),
            ),
    );
  }
}

String? _topicListCoverUrl(ForumTopic topic) {
  final url = topic.coverImageUrl?.trim();
  if (url == null || url.isEmpty || url.startsWith('assets/')) return null;
  return url;
}

class _TopicListCoverThumb extends StatelessWidget {
  const _TopicListCoverThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 52,
        height: 68,
        child: CofradeoNetworkImage(
          url: url,
          fit: BoxFit.cover,
          cacheSize: 160,
          errorWidget: ColoredBox(
            color: AppColors.backgroundElevated,
            child: Icon(
              Icons.image_outlined,
              size: 18,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

String _displayTitle(String title) {
  final parts = title.split(' · ');
  if (parts.length < 2) return title;
  return parts.sublist(1).join(' · ');
}

class _TopicAuthorLine extends StatelessWidget {
  const _TopicAuthorLine({
    required this.handle,
    required this.verified,
  });

  final String handle;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final normalized = handle.startsWith('@') ? handle : '@$handle';

    return Row(
      children: [
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: ForumTopicsTypography.card(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
              children: [
                const TextSpan(text: 'por '),
                TextSpan(
                  text: normalized,
                  style: ForumTopicsTypography.card(
                    color: AppColors.burgundy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textHeightBehavior:
                ForumTopicsTypography.compactTextHeightBehavior,
          ),
        ),
        if (verified) ...[
          const SizedBox(width: 3),
          const VerifiedAccountIcon(size: 11),
        ],
      ],
    );
  }
}
