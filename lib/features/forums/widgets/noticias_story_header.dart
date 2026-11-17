import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/forum.dart';
import '../forums_provider.dart';
import '../forum_topics_typography.dart';
import '../utils/noticias_forum.dart';
import '../utils/noticias_stories.dart';
import 'noticias_article_header.dart';
import 'noticias_editorial_feed.dart';

/// Detalle de una noticia. Si está unificada, el dedo cambia de cuenta.
class NoticiasStoryHeader extends ConsumerStatefulWidget {
  const NoticiasStoryHeader({
    super.key,
    required this.topic,
    required this.forumId,
    required this.displayViewCount,
  });

  final ForumTopic topic;
  final String forumId;
  final int displayViewCount;

  @override
  ConsumerState<NoticiasStoryHeader> createState() =>
      _NoticiasStoryHeaderState();
}

class _NoticiasStoryHeaderState extends ConsumerState<NoticiasStoryHeader> {
  int? _page;

  int _indexFor(NoticiasStory story) {
    final length = story.topics.length;
    if (length == 0) return 0;
    if (_page != null) return _page!.clamp(0, length - 1);
    final found = story.topics.indexWhere((t) => t.id == widget.topic.id);
    return found < 0 ? 0 : found;
  }

  void _goTo(int index, int length) {
    setState(() => _page = index.clamp(0, length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final loaded =
        ref.watch(forumTopicsProvider(noticiasForumId)).asData?.value;
    final story = storyForTopic(loaded, widget.topic);

    if (!story.isGrouped) {
      return NoticiasArticleHeader(
        topic: widget.topic,
        forumId: widget.forumId,
        topicId: widget.topic.id,
        displayViewCount: widget.displayViewCount,
      );
    }

    final index = _indexFor(story);
    final page = story.topics[index];
    final views = page.id == widget.topic.id
        ? widget.displayViewCount
        : page.viewCount;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 180) return;
        final delta = velocity < 0 ? 1 : -1;
        _goTo(_indexFor(story) + delta, story.topics.length);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                NoticiasAccountStack(
                  topics: story.topics,
                  activeIndex: index,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  '${index + 1} de ${story.topics.length}',
                  style: ForumTopicsTypography.card(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          NoticiasArticleHeader(
            topic: page,
            forumId: widget.forumId,
            topicId: page.id,
            displayViewCount: views,
          ),
        ],
      ),
    );
  }
}
