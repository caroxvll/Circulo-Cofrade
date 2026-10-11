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
import 'cofrade_rank_label.dart';
import 'forum_post_image.dart';
import 'noticias_editorial_feed.dart';
import 'related_forum_chip.dart';
import 'topic_follow_button.dart';
import 'topic_status_badge.dart';

const _articleInset = 16.0;

/// Detalle de Noticias estilo post (Twitter / Instagram): autor, media, texto.
class NoticiasArticleHeader extends StatelessWidget {
  const NoticiasArticleHeader({
    super.key,
    required this.topic,
    required this.forumId,
    required this.topicId,
    required this.displayViewCount,
  });

  final ForumTopic topic;
  final String forumId;
  final String topicId;
  final int displayViewCount;

  @override
  Widget build(BuildContext context) {
    final coverUrl = _remoteCoverUrl(topic);
    final body = normalizeStoredText(topic.body.trim());
    final excerpt = topic.excerpt.trim();
    final category = noticiasCategoryShort(topic);

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _articleInset,
              10,
              _articleInset,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NoticiasAuthorRow(
                  topic: topic,
                  forumId: forumId,
                  topicId: topicId,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _CategoryPill(label: category),
                    if (topic.relatedForumId != null)
                      RelatedForumChip(
                        relatedForumId: topic.relatedForumId!,
                        compact: true,
                      ),
                    if (topic.listStatusBadge != null)
                      TopicStatusBadge(topic: topic),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  topic.title,
                  style: AppTypography.newsHeadline(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 24,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (excerpt.isNotEmpty && body.isEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    excerpt,
                    style: AppTypography.newsBody(
                      color: AppColors.textSecondary,
                    ).copyWith(
                      fontSize: 16.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (coverUrl != null) ...[
            const SizedBox(height: 14),
            ForumPostImage(
              imageUrl: coverUrl,
              shareText: topic.title,
              borderRadius: BorderRadius.zero,
              maxPreviewHeight: 340,
              showExpandHint: false,
              fit: BoxFit.cover,
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _articleInset,
              16,
              _articleInset,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (body.isNotEmpty) _NoticiasArticleBody(text: body),
                const SizedBox(height: 18),
                _NoticiasArticleMetaRow(viewCount: displayViewCount),
              ],
            ),
          ),
        ],
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall(
          color: AppColors.burgundy,
        ).copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          height: 1.1,
        ),
      ),
    );
  }
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
    final rank = topic.authorId != null
        ? cofradeRankTitleForPoints(topic.authorTrophyPoints)
        : null;

    return Row(
      children: [
        CofradeoAvatar(
          imageUrl: topic.authorAvatarUrl,
          icon: topic.avatarIcon,
          size: 44,
          backgroundColor: AppColors.backgroundElevated,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: topic.authorId != null
                ? () => context.push('/perfil/usuario/${topic.authorId}')
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        handle,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                          color: topic.authorId != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ).copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (topic.authorVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedAccountIcon(size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (rank != null && rank.trim().isNotEmpty) ...[
                      Flexible(
                        child: CofradeRankLabel(title: rank, compact: true),
                      ),
                      Text(
                        ' · ',
                        style: TopicDetailTypography.meta(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 12.5),
                      ),
                    ],
                    Text(
                      topic.timeAgo,
                      style: TopicDetailTypography.meta(
                        color: AppColors.textMuted,
                      ).copyWith(fontSize: 12.5),
                    ),
                  ],
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

    final bodyStyle = AppTypography.newsBody(
      color: AppColors.textPrimary,
    );

    final children = <Widget>[];
    var usedDropCap = false;

    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 16));
      final block = blocks[i];
      if (!usedDropCap &&
          block.kind == ForumMarkdownBlockKind.paragraph &&
          block.lines.isNotEmpty) {
        children.add(
          _NewspaperDropCapParagraph(
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
            textAlign: TextAlign.justify,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Primer párrafo justificado con capitular (estilo periódico).
class _NewspaperDropCapParagraph extends StatelessWidget {
  const _NewspaperDropCapParagraph({
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
        textAlign: TextAlign.justify,
      );
    }

    final spans = <InlineSpan>[];
    var isFirstChar = true;

    for (final segment in segments) {
      if (segment.text.isEmpty) continue;
      final segmentStyle = segment.bold
          ? style.copyWith(fontWeight: FontWeight.w700)
          : style;

      if (isFirstChar) {
        final chars = segment.text.characters;
        final first = chars.first.toUpperCase();
        final rest = chars.skip(1).toString();
        spans.add(
          TextSpan(
            text: first,
            style: AppTypography.newsHeadline(
              color: AppColors.burgundyDark,
            ).copyWith(
              fontSize: 40,
              height: 0.9,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
        );
        if (rest.isNotEmpty) {
          spans.add(TextSpan(text: rest, style: segmentStyle));
        }
        isFirstChar = false;
      } else {
        spans.add(TextSpan(text: segment.text, style: segmentStyle));
      }
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.justify,
    );
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
  });

  final int viewCount;

  @override
  Widget build(BuildContext context) {
    final style = TopicDetailTypography.meta().copyWith(fontSize: 12.5);

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: AppColors.border.withValues(alpha: 0.55),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 15,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text('${formatCount(viewCount)} vistas', style: style),
          ],
        ),
      ],
    );
  }
}
