import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_markdown_blocks.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/forum_post_content.dart';
import '../../../core/widgets/mention_rich_text.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../topic_detail_typography.dart';
import '../utils/cofrade_gamification.dart';
import '../utils/reply_reactions.dart';
import 'cofrade_rank_label.dart';
import 'forum_post_image.dart';
import 'noticias_editorial_feed.dart';
import 'related_forum_chip.dart';
import 'topic_author_badge.dart';
import 'topic_follow_button.dart';
import 'topic_status_badge.dart';

const _articleInset = 16.0;

/// Cabecera editorial tipo periódico para el detalle de Noticias.
class NoticiasArticleHeader extends StatelessWidget {
  const NoticiasArticleHeader({
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
  Widget build(BuildContext context) {
    final coverUrl = _remoteCoverUrl(topic);
    final body = normalizeStoredText(topic.body.trim());
    final excerpt = topic.excerpt.trim();
    final category = noticiasCategoryShort(topic);
    final replyReactions = sortedReactionCounts(reactionBreakdown);

    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _articleInset,
          14,
          _articleInset,
          8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NoticiasAuthorRow(
              topic: topic,
              forumId: forumId,
              topicId: topicId,
            ),
            if (topic.relatedForumId != null) ...[
              const SizedBox(height: 14),
              RelatedForumChip(relatedForumId: topic.relatedForumId!),
            ],
            const SizedBox(height: 16),
            Text(
              'Actualidad · $category',
              style: AppTypography.displaySmall(
                color: AppColors.textPrimary,
              ).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                height: 1.15,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 1,
              color: AppColors.gold.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    topic.title,
                    style: AppTypography.displaySmall(
                      color: AppColors.textPrimary,
                    ).copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                if (topic.listStatusBadge != null) ...[
                  const SizedBox(width: 8),
                  TopicStatusBadge(topic: topic),
                ],
              ],
            ),
            // Sin entradilla si hay cuerpo: evita duplicar el mismo texto.
            if (excerpt.isNotEmpty && body.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                excerpt,
                style: AppTypography.bodyMedium(
                  color: AppColors.textSecondary,
                ).copyWith(
                  fontSize: 15,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (coverUrl != null) ...[
              const SizedBox(height: 16),
              ForumPostImage(
                imageUrl: coverUrl,
                shareText: topic.title,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                maxPreviewHeight: 280,
              ),
              const SizedBox(height: 6),
              Text(
                _imageCaption(topic),
                style: TopicDetailTypography.meta(
                  color: AppColors.textMuted,
                ).copyWith(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 18),
              _NoticiasArticleBody(text: body),
            ],
            const SizedBox(height: 16),
            _NoticiasArticleMetaRow(
              viewCount: displayViewCount,
              commentCount: displayCommentCount,
              replyReactionCounts: replyReactions,
            ),
          ],
        ),
      ),
    );
  }
}

String _imageCaption(ForumTopic topic) {
  final category = noticiasCategoryShort(topic);
  return '$category · Sevilla.';
}

String? _remoteCoverUrl(ForumTopic topic) {
  final url = topic.coverImageUrl?.trim();
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('assets/')) return null;
  return url;
}

class _NoticiasAuthorRow extends StatelessWidget {
  const _NoticiasAuthorRow({
    required this.topic,
    required this.forumId,
    required this.topicId,
  });

  final ForumTopic topic;
  final String forumId;
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final handle = topic.authorHandle.startsWith('@')
        ? topic.authorHandle
        : '@${topic.authorHandle}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CofradeoAvatar(
          imageUrl: topic.authorAvatarUrl,
          icon: topic.avatarIcon,
          size: 36,
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
                          fontWeight: FontWeight.w700,
                        ).copyWith(fontSize: 13),
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
        if (topic.isPublished) ...[
          const SizedBox(width: 8),
          TopicFollowButton(
            forumId: forumId,
            topicId: topicId,
            compact: true,
          ),
        ],
      ],
    );
  }
}

class _NoticiasArticleBody extends StatelessWidget {
  const _NoticiasArticleBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final blocks = parseForumMarkdownBlocks(text);
    if (blocks.isEmpty) return const SizedBox.shrink();

    final bodyStyle = AppTypography.bodyMedium(
      color: AppColors.textPrimary,
    ).copyWith(
      fontSize: 15.5,
      height: 1.65,
      fontWeight: FontWeight.w400,
    );

    final children = <Widget>[];
    var usedDropCap = false;

    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 14));
      final block = blocks[i];
      if (!usedDropCap &&
          block.kind == ForumMarkdownBlockKind.paragraph &&
          block.lines.isNotEmpty) {
        children.add(
          _DropCapParagraph(
            text: block.lines.first,
            style: bodyStyle,
          ),
        );
        usedDropCap = true;
      } else {
        children.add(
          ForumPostContent(
            text: switch (block.kind) {
              ForumMarkdownBlockKind.paragraph => block.lines.first,
              ForumMarkdownBlockKind.bulletList => [
                  for (final line in block.lines) '- $line',
                ].join('\n'),
              ForumMarkdownBlockKind.orderedList => [
                  for (var j = 0; j < block.lines.length; j++)
                    '${j + 1}. ${block.lines[j]}',
                ].join('\n'),
              ForumMarkdownBlockKind.blockquote => [
                  for (final line in block.lines) '> $line',
                ].join('\n'),
            },
            style: bodyStyle,
            subtleLinks: true,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _DropCapParagraph extends StatelessWidget {
  const _DropCapParagraph({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final prepared = trimmed
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (m) => m.group(1) ?? '',
        )
        .replaceAll('__', '**');
    final segments = _parseBoldSegments(prepared);
    if (segments.isEmpty) {
      return MentionRichText(
        text: trimmed,
        style: style,
        subtleLinks: true,
      );
    }

    final spans = <InlineSpan>[];
    var isFirstChar = true;

    for (final segment in segments) {
      if (segment.text.isEmpty) continue;
      final boldStyle = segment.bold
          ? style.copyWith(fontWeight: FontWeight.w700)
          : style;

      if (isFirstChar) {
        final chars = segment.text.characters;
        final first = chars.first.toUpperCase();
        final rest = chars.skip(1).toString();
        spans.add(
          TextSpan(
            text: first,
            style: AppTypography.displaySmall(
              color: AppColors.burgundy,
            ).copyWith(
              fontSize: 40,
              height: 0.92,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.8,
            ),
          ),
        );
        if (rest.isNotEmpty) {
          spans.add(TextSpan(text: rest, style: boldStyle));
        }
        isFirstChar = false;
      } else {
        spans.add(TextSpan(text: segment.text, style: boldStyle));
      }
    }

    // Capitular integrada en el mismo flujo tipográfico (sin hueco de Row).
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

List<({String text, bool bold})> _parseBoldSegments(String input) {
  final out = <({String text, bool bold})>[];
  final re = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  var start = 0;
  for (final match in re.allMatches(input)) {
    if (match.start > start) {
      out.add((text: input.substring(start, match.start), bold: false));
    }
    out.add((text: match.group(1) ?? '', bold: true));
    start = match.end;
  }
  if (start < input.length) {
    out.add((text: input.substring(start), bold: false));
  }
  if (out.isEmpty && input.isNotEmpty) {
    out.add((text: input, bold: false));
  }
  return out;
}

class _NoticiasArticleMetaRow extends StatelessWidget {
  const _NoticiasArticleMetaRow({
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

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: AppColors.border.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.visibility_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('${formatCount(viewCount)} vistas', style: style),
            const SizedBox(width: 14),
            Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              commentCount == 1 ? '1 respuesta' : '$commentCount respuestas',
              style: style,
            ),
            if (replyReactionCounts.isNotEmpty) ...[
              const SizedBox(width: 14),
              for (final entry in replyReactionCounts.take(3)) ...[
                Text(entry.key, style: style.copyWith(fontSize: 13)),
                const SizedBox(width: 2),
                Text('${entry.value}', style: style),
                const SizedBox(width: 8),
              ],
            ],
          ],
        ),
      ],
    );
  }
}
