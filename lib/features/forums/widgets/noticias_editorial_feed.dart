import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../data/topic_icon_assets.dart';
import '../forum_topics_typography.dart';
import 'related_forum_chip.dart';

/// Slivers del feed editorial de Noticias.
List<Widget> buildNoticiasEditorialSlivers({
  required List<ForumTopic> topics,
  required bool showAllLatest,
  required VoidCallback onToggleShowAll,
  required void Function(ForumTopic topic) onOpenTopic,
  Widget? sponsoredSlot,
  required double bottomPadding,
}) {
  final listed = [for (final t in topics) if (t.isListed) t];
  final pinned = [
    for (final t in listed)
      if (t.isPinned) t,
  ]..sort((a, b) => a.pinSortOrder.compareTo(b.pinSortOrder));
  final community = [
    for (final t in listed)
      if (!t.isPinned) t,
  ];

  final featured = pinned.isEmpty ? null : pinned.first;
  final rest = [
    if (featured != null) ...pinned.skip(1),
    ...community,
  ];

  final slivers = <Widget>[];

  if (featured != null) {
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Destacada',
            style: AppTypography.displaySmall(
              color: AppColors.burgundyDark,
            ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverToBoxAdapter(
          child: NoticiasFeaturedEditorialCard(
            topic: featured,
            onTap: () => onOpenTopic(featured),
          ),
        ),
      ),
    );
  }

  if (sponsoredSlot != null) {
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(child: sponsoredSlot),
      ),
    );
  }

  if (rest.isEmpty && featured == null) {
    slivers.add(
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 24, 8),
          child: Text(
            'Aún no hay noticias.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  } else if (rest.isNotEmpty) {
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Últimas noticias',
                  style: AppTypography.displaySmall(
                    color: AppColors.burgundyDark,
                  ).copyWith(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              InkWell(
                onTap: onToggleShowAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    showAllLatest ? 'Ver menos ›' : 'Ver todas ›',
                    style: ForumTopicsTypography.card(
                      color: AppColors.burgundy,
                      fontWeight: FontWeight.w700,
                    ).copyWith(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (showAllLatest) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: rest.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final topic = rest[index];
              return NoticiasListEditorialCard(
                topic: topic,
                onTap: () => onOpenTopic(topic),
              );
            },
          ),
        ),
      );
    } else {
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 248,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              itemCount: rest.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final topic = rest[index];
                return NoticiasRailCard(
                  topic: topic,
                  onTap: () => onOpenTopic(topic),
                );
              },
            ),
          ),
        ),
      );
    }
  }

  slivers.add(
    SliverPadding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
    ),
  );

  return slivers;
}

String noticiasCategoryShort(ForumTopic topic) {
  final id = topic.relatedForumId;
  return switch (id) {
    'pentagrama-cofrade' => 'Bandas',
    'martillo-trabajadera' => 'Costal',
    'hermandades' => 'Institucional',
    'foro-cofradiero' => 'Comunidad',
    _ => 'Arte y patrimonio',
  };
}

class NoticiasFeaturedEditorialCard extends StatelessWidget {
  const NoticiasFeaturedEditorialCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  final ForumTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final excerpt = topic.excerpt.trim();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.goldDark.withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundyDark.withValues(alpha: 0.1),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 148,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 132,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _NoticiasEditorialCover(topic: topic),
                        // Fundido hacia el texto (más editorial).
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 28,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  AppColors.surface.withValues(alpha: 0),
                                  AppColors.surface.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 11,
                                  color: AppColors.burgundyDark,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'DESTACADA',
                                  style: ForumTopicsTypography.card(
                                    color: AppColors.burgundyDark,
                                    fontWeight: FontWeight.w800,
                                  ).copyWith(
                                    fontSize: 9,
                                    letterSpacing: 0.4,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 3,
                    color: AppColors.burgundy.withValues(alpha: 0.85),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _GoldCategoryTag(
                                label: noticiasCategoryShort(topic),
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  topic.timeAgo,
                                  style: ForumTopicsTypography.card(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ).copyWith(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            topic.title,
                            style: AppTypography.displaySmall(
                              color: AppColors.textPrimary,
                            ).copyWith(
                              fontSize: 16.5,
                              height: 1.18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: excerpt.isEmpty ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (excerpt.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              excerpt,
                              style: ForumTopicsTypography.card(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ).copyWith(fontSize: 11.5, height: 1.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const Spacer(),
                          Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    5,
                                    10,
                                    5,
                                  ),
                                  child: Text(
                                    'Leer noticia ›',
                                    style: ForumTopicsTypography.card(
                                      color: AppColors.burgundyDark,
                                      fontWeight: FontWeight.w800,
                                    ).copyWith(fontSize: 10.5, height: 1),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.visibility_outlined,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                formatCount(topic.viewCount),
                                style: ForumTopicsTypography.card(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ).copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class NoticiasRailCard extends StatelessWidget {
  const NoticiasRailCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  final ForumTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 1.5,
        shadowColor: AppColors.burgundyDark.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 104,
                    child: _NoticiasEditorialCover(topic: topic),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GoldCategoryTag(
                          label: noticiasCategoryShort(topic),
                          compact: true,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          topic.title,
                          style: AppTypography.displaySmall(
                            color: AppColors.textPrimary,
                          ).copyWith(fontSize: 14, height: 1.15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic.excerpt,
                          style: ForumTopicsTypography.card(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ).copyWith(fontSize: 11, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              formatCount(topic.viewCount),
                              style: ForumTopicsTypography.card(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ).copyWith(fontSize: 10),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${topic.commentCount}',
                              style: ForumTopicsTypography.card(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ).copyWith(fontSize: 10),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.bookmark_border_rounded,
                              size: 16,
                              color: AppColors.textMuted.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoticiasListEditorialCard extends StatelessWidget {
  const NoticiasListEditorialCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  final ForumTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: AppColors.burgundyDark.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 92,
                    height: 72,
                    child: _NoticiasEditorialCover(topic: topic),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: AppTypography.displaySmall(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 15, height: 1.15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      if (topic.relatedForumId != null)
                        RelatedForumChip(
                          relatedForumId: topic.relatedForumId!,
                          compact: true,
                        )
                      else
                        _GoldCategoryTag(
                          label: noticiasCategoryShort(topic),
                          compact: true,
                        ),
                      const SizedBox(height: 5),
                      Text(
                        topic.excerpt,
                        style: ForumTopicsTypography.card(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ).copyWith(fontSize: 11, height: 1.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            topic.timeAgo,
                            style: ForumTopicsTypography.card(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ).copyWith(fontSize: 10),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.visibility_outlined,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatCount(topic.viewCount),
                            style: ForumTopicsTypography.card(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ).copyWith(fontSize: 10),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${topic.commentCount}',
                            style: ForumTopicsTypography.card(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ).copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldCategoryTag extends StatelessWidget {
  const _GoldCategoryTag({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.28)),
      ),
      child: Text(
        label.toUpperCase(),
        style: ForumTopicsTypography.card(
          color: AppColors.goldDark,
          fontWeight: FontWeight.w700,
        ).copyWith(fontSize: compact ? 9 : 10, letterSpacing: 0.3, height: 1.1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NoticiasEditorialCover extends StatelessWidget {
  const _NoticiasEditorialCover({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final cover = topicCoverImageSource(topic);
    final icon = topicDisplayIcon(topic);

    Widget placeholder() => ColoredBox(
          color: AppColors.burgundy.withValues(alpha: 0.92),
          child: Center(
            child: Icon(icon, color: AppColors.gold, size: 28),
          ),
        );

    if (cover == null) return placeholder();
    if (topicCoverIsAsset(cover)) {
      return Image.asset(
        cover,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        cacheWidth: ImageDecodeCache.px(context, 220),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    return CofradeoNetworkImage(
      url: cover,
      fit: BoxFit.cover,
      cacheSize: 220,
      errorWidget: placeholder(),
    );
  }
}
