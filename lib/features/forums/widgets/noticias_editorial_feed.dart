import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_asset_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../data/topic_icon_assets.dart';
import '../forum_topics_typography.dart';
import '../utils/noticias_forum.dart';
import '../utils/noticias_stories.dart';

const _gutter = 12.0;
const _railCardWidth = 168.0;
const _railCardHeight = 248.0;
const _railCardHeightCompact = 228.0;
/// Recupera el hueco que deja el solape del hero cuando el banner inferior está activo.
const _dockedAdTopPull = 22.0;

/// Slivers del feed editorial de Noticias:
/// última noticia a ancho completo + carril horizontal del resto.
List<Widget> buildNoticiasEditorialSlivers({
  required List<ForumTopic> topics,
  required bool showAllLatest,
  required VoidCallback onToggleShowAll,
  required void Function(ForumTopic topic) onOpenTopic,
  Widget? sponsoredSlot,
  required double bottomPadding,
  /// Banner docked encima de la bottom nav: compacta márgenes superiores.
  bool dockedAdActive = false,
}) {
  final stories = groupNoticiasForFeed(topics);
  final featured = stories.isEmpty ? null : stories.first;
  final rest = featured == null
      ? const <NoticiasStory>[]
      : stories.skip(1).toList();
  final railHeight =
      dockedAdActive ? _railCardHeightCompact : _railCardHeight;

  final slivers = <Widget>[];

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
  } else {
    final feedChildren = <Widget>[
      if (featured != null) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 4),
          child: Text(
            'Última hora',
            style: AppTypography.newsHeadline(
              color: AppColors.burgundyDark,
            ).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          child: featured.isGrouped
              ? NoticiasFeaturedStoryCarousel(
                  story: featured,
                  onOpen: onOpenTopic,
                  compact: dockedAdActive,
                )
              : NoticiasFeaturedEditorialCard(
                  topic: featured.lead,
                  onTap: () => onOpenTopic(featured.lead),
                  compact: dockedAdActive,
                ),
        ),
      ],
      if (sponsoredSlot != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 0),
          child: sponsoredSlot,
        ),
      if (rest.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Más noticias',
                  style: AppTypography.newsHeadline(
                    color: AppColors.burgundyDark,
                  ).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
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
        if (showAllLatest)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            child: Column(
              children: [
                for (var i = 0; i < rest.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  NoticiasListEditorialCard(
                    topic: rest[i].lead,
                    accounts: rest[i].isGrouped ? rest[i].topics : null,
                    onTap: () => onOpenTopic(rest[i].lead),
                  ),
                ],
              ],
            ),
          )
        else
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _gutter),
              itemCount: rest.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final story = rest[index];
                return SizedBox(
                  width: _railCardWidth,
                  child: NoticiasRailCard(
                    topic: story.lead,
                    accounts: story.isGrouped ? story.topics : null,
                    onTap: () => onOpenTopic(story.lead),
                  ),
                );
              },
            ),
          ),
      ],
      // Compensa el translate superior sin abrir hueco entre secciones.
      if (dockedAdActive) const SizedBox(height: _dockedAdTopPull),
    ];

    slivers.add(
      SliverToBoxAdapter(
        child: Transform.translate(
          offset: Offset(0, dockedAdActive ? -_dockedAdTopPull : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: feedChildren,
          ),
        ),
      ),
    );
  }

  slivers.add(
    SliverToBoxAdapter(
      child: SizedBox(height: bottomPadding),
    ),
  );

  return slivers;
}

String noticiasCategoryShort(ForumTopic topic) {
  return noticiasCategoryLabel(topic.relatedForumId);
}

class NoticiasFeaturedEditorialCard extends StatelessWidget {
  const NoticiasFeaturedEditorialCard({
    super.key,
    required this.topic,
    required this.onTap,
    this.compact = false,
  });

  final ForumTopic topic;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final excerpt = topic.excerpt.trim();
    final coverHeight = compact ? 142.0 : 168.0;

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
                  height: coverHeight,
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
                                'ÚLTIMA HORA',
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
                      _NoticiasByline(topic: topic),
                      const SizedBox(height: 8),
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
    this.accounts,
  });

  final ForumTopic topic;
  final VoidCallback onTap;

  /// Cuentas unificadas. En el carril no hay carrusel: el dedo ya mueve las fichas.
  final List<ForumTopic>? accounts;

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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NoticiasEditorialCover(topic: topic),
                      if (accounts != null && accounts!.length > 1)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: NoticiasAccountStack(topics: accounts!),
                        ),
                    ],
                  ),
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
                          Expanded(
                            child: _NoticiasByline(
                              topic: topic,
                              avatarSize: 16,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            topic.timeAgo,
                            style: ForumTopicsTypography.card(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ).copyWith(fontSize: 9.5),
                            maxLines: 1,
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
    this.accounts,
  });

  final ForumTopic topic;
  final VoidCallback onTap;
  final List<ForumTopic>? accounts;

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
                      const SizedBox(height: 6),
                      _NoticiasByline(
                        topic: topic,
                        avatarSize: 18,
                        fontSize: 11,
                      ),
                      if (accounts != null && accounts!.length > 1) ...[
                        const SizedBox(height: 6),
                        NoticiasAccountStack(topics: accounts!, size: 18),
                      ],
                      const SizedBox(height: 5),
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

/// Ficha de última hora cuando la junta ha unido varias cuentas.
/// El dedo pasa de una versión a otra. La primera en publicarse va delante.
class NoticiasFeaturedStoryCarousel extends StatefulWidget {
  const NoticiasFeaturedStoryCarousel({
    super.key,
    required this.story,
    required this.onOpen,
    this.compact = false,
  });

  final NoticiasStory story;
  final void Function(ForumTopic topic) onOpen;
  final bool compact;

  @override
  State<NoticiasFeaturedStoryCarousel> createState() =>
      _NoticiasFeaturedStoryCarouselState();
}

class _NoticiasFeaturedStoryCarouselState
    extends State<NoticiasFeaturedStoryCarousel> {
  late final PageController _pages;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics = widget.story.topics;
    final coverHeight = widget.compact ? 132.0 : 158.0;
    final pageHeight = coverHeight + (widget.compact ? 118 : 132);

    return DecoratedBox(
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
              height: pageHeight,
              child: PageView.builder(
                controller: _pages,
                itemCount: topics.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final excerpt = topic.excerpt.trim();
                  return GestureDetector(
                    onTap: () => widget.onOpen(topic),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: coverHeight,
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
                                left: 12,
                                right: 12,
                                bottom: 12,
                                child: Text(
                                  topic.title,
                                  style: AppTypography.newsHeadline(
                                    color: Colors.white,
                                  ).copyWith(
                                    fontSize: 17,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              CofradeoAvatar(
                                imageUrl: topic.authorAvatarUrl,
                                icon: topic.avatarIcon,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  topic.authorHandle.startsWith('@')
                                      ? topic.authorHandle
                                      : '@${topic.authorHandle}',
                                  style: ForumTopicsTypography.card(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ).copyWith(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                topic.timeAgo,
                                style: ForumTopicsTypography.card(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ).copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (excerpt.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                            child: Text(
                              excerpt,
                              style: ForumTopicsTypography.card(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ).copyWith(fontSize: 12.5, height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  NoticiasAccountStack(topics: topics, activeIndex: _index),
                  const SizedBox(width: 8),
                  Text(
                    '${_index + 1} de ${topics.length}',
                    style: ForumTopicsTypography.card(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ).copyWith(fontSize: 11),
                  ),
                  const Spacer(),
                  for (var i = 0; i < topics.length; i++)
                    Container(
                      width: i == _index ? 14 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.burgundy
                            : AppColors.gold.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(99),
                      ),
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

class _NoticiasByline extends StatelessWidget {
  const _NoticiasByline({
    required this.topic,
    this.avatarSize = 22,
    this.fontSize = 12,
  });

  final ForumTopic topic;
  final double avatarSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final raw = topic.authorHandle.trim();
    final handle = raw.isEmpty
        ? '@cofradeo'
        : (raw.startsWith('@') ? raw : '@$raw');

    return Row(
      children: [
        CofradeoAvatar(
          imageUrl: topic.authorAvatarUrl,
          icon: topic.avatarIcon,
          size: avatarSize,
        ),
        SizedBox(width: avatarSize > 18 ? 8 : 5),
        Expanded(
          child: Text(
            handle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ForumTopicsTypography.card(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ).copyWith(fontSize: fontSize, height: 1.1),
          ),
        ),
      ],
    );
  }
}

class NoticiasAccountStack extends StatelessWidget {
  const NoticiasAccountStack({
    super.key,
    required this.topics,
    this.activeIndex,
    this.size = 16,
  });

  final List<ForumTopic> topics;
  final int? activeIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = topics.take(4).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Transform.translate(
            offset: Offset(i == 0 ? 0 : -6.0 * i, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: activeIndex == i
                      ? AppColors.gold
                      : AppColors.surface,
                  width: 1.5,
                ),
              ),
              child: CofradeoAvatar(
                imageUrl: shown[i].authorAvatarUrl,
                icon: shown[i].avatarIcon,
                size: size,
              ),
            ),
          ),
        if (topics.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+${topics.length - shown.length}',
              style: ForumTopicsTypography.card(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ).copyWith(fontSize: 10),
            ),
          ),
      ],
    );
  }
}
