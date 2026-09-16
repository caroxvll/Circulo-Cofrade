import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/forum_post_content.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../topic_detail_typography.dart';
import '../utils/cofrade_gamification.dart';
import '../utils/reply_reactions.dart';
import 'cofrade_rank_label.dart';
import 'forum_post_image.dart';
import 'hermandad_board_header.dart';
import 'related_forum_chip.dart';
import 'topic_author_badge.dart';
import 'topic_follow_button.dart';
import 'topic_status_badge.dart';
import 'season_hub_chip.dart';
import '../utils/season_hub_context.dart';
import '../utils/noticias_forum.dart';

/// Margen horizontal del scroll del detalle de tema (para alinear el hero).
const topicDetailHorizontalInset = 16.0;

class TopicDetailHeader extends StatelessWidget {
  const TopicDetailHeader({
    super.key,
    required this.topic,
    required this.forumId,
    required this.topicId,
    required this.isHermandadBoard,
    required this.displayCommentCount,
    required this.displayViewCount,
    this.displayTotalReactions = 0,
    this.reactionBreakdown = const {},
    this.guide,
  });

  final ForumTopic topic;
  final String forumId;
  final String topicId;
  final bool isHermandadBoard;
  final int displayCommentCount;
  final int displayViewCount;
  final int displayTotalReactions;
  final Map<String, int> reactionBreakdown;
  final Widget? guide;

  @override
  Widget build(BuildContext context) {
    if (isHermandadBoard) {
      return HermandadBoardHeader(
        topic: topic,
        forumId: forumId,
        topicId: topicId,
        displayCommentCount: displayCommentCount,
        displayViewCount: displayViewCount,
        displayTotalReactions: displayTotalReactions,
        reactionBreakdown: reactionBreakdown,
      );
    }

    final hasCover = _remoteCoverUrl(topic) != null;
    final hasBody = topic.body.trim().isNotEmpty;
    final replyReactions = sortedReactionCounts(reactionBreakdown);

    return ColoredBox(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.9),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            topicDetailHorizontalInset,
            16,
            topicDetailHorizontalInset,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSeasonCommunityTopicDetail(topic) &&
                  topic.seasonKey != null) ...[
                SeasonHubContextBar(
                  forumId: forumId,
                  seasonKey: topic.seasonKey!,
                ),
                const SizedBox(height: 14),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _TopicAuthorRow(topic: topic)),
                  if (topic.isPublished) ...[
                    const SizedBox(width: 8),
                    TopicFollowButton(
                      forumId: forumId,
                      topicId: topicId,
                      isHermandadBoard: isHermandadBoard,
                      compact: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      topic.title,
                      style: TopicDetailTypography.heroTitle(),
                    ),
                  ),
                  if (topic.listStatusBadge != null) ...[
                    const SizedBox(width: 8),
                    TopicStatusBadge(topic: topic),
                  ],
                ],
              ),
              if (topic.relatedForumId != null) ...[
                const SizedBox(height: 10),
                RelatedForumChip(relatedForumId: topic.relatedForumId!),
              ],
              if (hasCover) ...[
                const SizedBox(height: 10),
                const _EditorialTitleRule(),
              ],
              if (hasBody ||
                  hasCover ||
                  guide != null ||
                  displayViewCount > 0 ||
                  displayCommentCount > 0 ||
                  replyReactions.isNotEmpty) ...[
                SizedBox(height: hasCover ? 12 : 14),
                _TopicEditorialBody(
                  topic: topic,
                  isHermandadBoard: isHermandadBoard,
                ),
                if (guide != null) ...[
                  const SizedBox(height: 12),
                  guide!,
                ],
                const SizedBox(height: 12),
                _TopicMetaRow(
                  viewCount: displayViewCount,
                  commentCount: displayCommentCount,
                  replyReactionCounts: replyReactions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? _remoteCoverUrl(ForumTopic topic) {
  final url = topic.coverImageUrl?.trim();
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('assets/')) return null;
  return url;
}

/// Portada + descripción en composición editorial (lado a lado o apilado).
class _TopicEditorialBody extends StatelessWidget {
  const _TopicEditorialBody({
    required this.topic,
    required this.isHermandadBoard,
  });

  final ForumTopic topic;
  final bool isHermandadBoard;

  /// En móvil / tablet estrecha: portada arriba y texto debajo (como la preview admin).
  /// Solo lado a lado en pantallas anchas.
  static const _stackBelowWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    final coverUrl = _remoteCoverUrl(topic);
    final body = topic.body.trim();
    final hasBody = body.isNotEmpty;

    if (coverUrl == null && !hasBody) {
      return const SizedBox.shrink();
    }

    if (coverUrl == null) {
      return ForumPostContent(
        text: normalizeStoredText(body),
        style: TopicDetailTypography.body().copyWith(
          fontSize: TopicDetailTypography.bodySize + 0.5,
          height: 1.55,
        ),
        subtleLinks: true,
        premium: isHermandadBoard,
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    // Noticias y pantallas < 720: siempre apilado (evita columna de texto estrecha).
    final stack = isNoticiasForum(topic.forumId) || width < _stackBelowWidth;
    final compact = width < 520;

    final image = ForumPostImage(
      imageUrl: coverUrl,
      shareText: topic.title,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      maxPreviewHeight: stack ? 420 : 480,
    );

    if (!hasBody) return image;

    final caption = _EditorialCaptionColumn(
      text: normalizeStoredText(body),
      compact: compact || stack,
    );

    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          image,
          const SizedBox(height: 16),
          caption,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: compact ? 4 : 5,
          child: image,
        ),
        SizedBox(width: compact ? 14 : 20),
        Expanded(
          flex: 6,
          child: caption,
        ),
      ],
    );
  }
}

/// Filete corto bajo el título cuando hay portada.
class _EditorialTitleRule extends StatelessWidget {
  const _EditorialTitleRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 2,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// Columna de lectura junto al cartel (sin filete: ya va bajo el título).
class _EditorialCaptionColumn extends StatelessWidget {
  const _EditorialCaptionColumn({
    required this.text,
    required this.compact,
  });

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ForumPostContent(
      text: text,
      style: TopicDetailTypography.body().copyWith(
        fontSize: compact ? 12.5 : 13.0,
        height: 1.62,
        color: AppColors.textSecondary,
        letterSpacing: 0.12,
        fontWeight: FontWeight.w400,
      ),
      subtleLinks: true,
      premium: true,
    );
  }
}

class TopicDetailRepliesHeader extends StatelessWidget {
  const TopicDetailRepliesHeader({
    super.key,
    required this.isHermandadBoard,
    required this.commentCount,
    this.sectionSubtitle,
  });

  final bool isHermandadBoard;
  final int commentCount;
  final String? sectionSubtitle;

  @override
  Widget build(BuildContext context) {
    final title = isHermandadBoard
        ? 'Información oficial'
        : commentCount > 0
            ? 'Respuestas ($commentCount)'
            : 'Respuestas';
    final subtitle = sectionSubtitle ??
        (isHermandadBoard
            ? (commentCount > 0
                ? 'Noticias, cultos, actos y patrimonio · más recientes primero'
                : 'Noticias, cultos, actos y patrimonio')
            : (commentCount > 0 ? 'Más recientes primero' : null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.85),
                    AppColors.goldDark,
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TopicDetailTypography.sectionTitle(),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TopicDetailTypography.sectionSubtitle(),
          ),
        ],
      ],
    );
  }
}

class _TopicAuthorRow extends StatelessWidget {
  const _TopicAuthorRow({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final handle = topic.authorHandle.startsWith('@')
        ? topic.authorHandle
        : '@${topic.authorHandle}';

    return Row(
      children: [
        CofradeoAvatar(
          imageUrl: topic.authorAvatarUrl,
          icon: topic.avatarIcon,
          size: 32,
          backgroundColor: AppColors.backgroundElevated,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: topic.authorId != null
                ? () => context.push('/perfil/usuario/${topic.authorId}')
                : null,
            borderRadius: BorderRadius.circular(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        handle,
                        overflow: TextOverflow.ellipsis,
                        style: TopicDetailTypography.meta(
                          color: topic.authorId != null
                              ? AppColors.burgundy
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (topic.authorVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedAccountIcon(size: 13),
                    ],
                    const SizedBox(width: 6),
                    const TopicAuthorBadge(),
                  ],
                ),
                if (topic.authorId != null) ...[
                  const SizedBox(height: 1),
                  CofradeRankLabel(
                    title: cofradeRankTitleForPoints(topic.authorTrophyPoints),
                  ),
                ],
                Text(
                  topic.timeAgo,
                  style: TopicDetailTypography.meta(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicMetaRow extends StatelessWidget {
  const _TopicMetaRow({
    required this.viewCount,
    required this.commentCount,
    this.replyReactionCounts = const [],
  });

  final int viewCount;
  final int commentCount;
  final List<MapEntry<String, int>> replyReactionCounts;

  @override
  Widget build(BuildContext context) {
    final style = TopicDetailTypography.meta();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 6,
      children: [
        Icon(Icons.visibility_outlined, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text('${formatCount(viewCount)} vistas', style: style),
        if (commentCount > 0) ...[
          const _MetaDot(),
          Icon(
            Icons.chat_bubble_outline,
            size: 12,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            commentCount == 1 ? '1 respuesta' : '$commentCount respuestas',
            style: style,
          ),
        ],
        for (final entry in replyReactionCounts) ...[
          const _MetaDot(),
          Text(
            entry.key,
            style: const TextStyle(
              fontSize: 14,
              height: 1,
              fontFamily: 'Segoe UI Emoji',
              fontFamilyFallback: [
                'Apple Color Emoji',
                'Noto Color Emoji',
                'Twemoji Mozilla',
              ],
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            formatCount(entry.value),
            style: style.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.border,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
