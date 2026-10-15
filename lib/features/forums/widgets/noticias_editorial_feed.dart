import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_asset_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../data/topic_icon_assets.dart';
import '../forum_topics_typography.dart';
import 'related_forum_chip.dart';

const _gutter = 12.0;
const _previewGridCount = 4;

/// Slivers del feed editorial de Noticias (denso, a ancho útil).
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
          padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 4),
          child: Text(
            'Destacada',
            style: AppTypography.newsHeadline(
              color: AppColors.burgundyDark,
            ).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 0),
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
        padding: const EdgeInsets.fromLTRB(_gutter, 10, _gutter, 0),
        sliver: SliverToBoxAdapter(child: sponsoredSlot),
      ),
    );
  }

  if (rest.isEmpty && featured == null) {
    slivers.add(
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 8),
          child: Text(
            'Aún no hay noticias.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  } else if (rest.isNotEmpty) {
    final canExpand = rest.length > _previewGridCount;
    final gridItems = showAllLatest || !canExpand
        ? rest
        : rest.take(_previewGridCount).toList();

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 10, _gutter, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Últimas noticias',
                  style: AppTypography.newsHeadline(
                    color: AppColors.burgundyDark,
                  ).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              if (canExpand)
                InkWell(
                  onTap: onToggleShowAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
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

    if (showAllLatest && rest.length > _previewGridCount) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          sliver: SliverList.separated(
            itemCount: rest.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
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
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.74,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final topic = gridItems[index];
                return NoticiasRailCard(
                  topic: topic,
                  onTap: () => onOpenTopic(topic),
                );
              },
              childCount: gridItems.length,
            ),
          ),
        ),
      );
    }
  }

  slivers.add(
    SliverToBoxAdapter(
      child: SizedBox(height: bottomPadding),
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.goldDark.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundyDark.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 168,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NoticiasEditorialCover(topic: topic, wide: true),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x33000000),
                              Color(0x00000000),
                              Color(0x99000000),
                            ],
                            stops: [0, 0.45, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: AppColors.burgundyDark,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'DESTACADA',
                                style: ForumTopicsTypography.card(
                                  color: AppColors.burgundyDark,
                                  fontWeight: FontWeight.w800,
                                ).copyWith(
                                  fontSize: 9.5,
                                  letterSpacing: 0.4,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _GoldCategoryTag(
                              label: noticiasCategoryShort(topic),
                              compact: true,
                              onDark: true,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              topic.title,
                              style: AppTypography.newsHeadline(
                                color: Colors.white,
                              ).copyWith(
                                fontSize: 18,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (excerpt.isNotEmpty) ...[
                        Text(
                          excerpt,
                          style: ForumTopicsTypography.card(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ).copyWith(fontSize: 12.5, height: 1.35),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Text(
                            topic.timeAgo,
                            style: ForumTopicsTypography.card(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ).copyWith(fontSize: 11),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.visibility_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatCount(topic.viewCount),
                            style: ForumTopicsTypography.card(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ).copyWith(fontSize: 11),
                          ),
                          const Spacer(),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(11, 6, 11, 6),
                              child: Text(
                                'Leer noticia ›',
                                style: ForumTopicsTypography.card(
                                  color: AppColors.burgundyDark,
                                  fontWeight: FontWeight.w800,
                                ).copyWith(fontSize: 11, height: 1),
                              ),
                            ),
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1.2,
      shadowColor: AppColors.burgundyDark.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: SizedBox(
                  height: 108,
                  child: _NoticiasEditorialCover(topic: topic),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GoldCategoryTag(
                        label: noticiasCategoryShort(topic),
                        compact: true,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        topic.title,
                        style: AppTypography.newsHeadline(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 13.5, height: 1.15),
                        maxLines: 3,
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
                          const Spacer(),
                          Text(
                            topic.timeAgo,
                            style: ForumTopicsTypography.card(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ).copyWith(fontSize: 9.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: AppColors.burgundyDark.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 96,
                    height: 76,
                    child: _NoticiasEditorialCover(topic: topic),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: AppTypography.newsHeadline(
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
                        ).copyWith(fontSize: 11.5, height: 1.3),
                        maxLines: 2,
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
  const _GoldCategoryTag({
    required this.label,
    this.compact = false,
    this.onDark = false,
  });

  final String label;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? AppColors.goldPale : AppColors.goldDark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.black.withValues(alpha: 0.35)
            : AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onDark
              ? AppColors.gold.withValues(alpha: 0.45)
              : AppColors.goldDark.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: ForumTopicsTypography.card(
          color: fg,
          fontWeight: FontWeight.w700,
        ).copyWith(fontSize: compact ? 9 : 10, letterSpacing: 0.3, height: 1.1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NoticiasEditorialCover extends StatelessWidget {
  const _NoticiasEditorialCover({
    required this.topic,
    this.wide = false,
  });

  final ForumTopic topic;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cover = topicCoverImageSource(topic);
    final icon = topicDisplayIcon(topic);
    final cache = wide ? 720.0 : 320.0;

    Widget placeholder() => ColoredBox(
          color: AppColors.burgundy.withValues(alpha: 0.92),
          child: Center(
            child: Icon(icon, color: AppColors.gold, size: wide ? 36 : 28),
          ),
        );

    if (cover == null) return placeholder();
    if (topicCoverIsAsset(cover)) {
      return CofradeoAssetImage(
        assetPath: cover,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        cacheWidth: ImageDecodeCache.px(context, cache),
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    return CofradeoNetworkImage(
      url: cover,
      fit: BoxFit.cover,
      cacheSize: cache,
      placeholder: ColoredBox(
        color: AppColors.burgundy.withValues(alpha: 0.55),
      ),
      errorWidget: placeholder(),
    );
  }
}
