import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/forum.dart';
import '../../forums/data/mock_forums.dart';
import '../../forums/forum_topics_typography.dart';
import '../../forums/forums_provider.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/utils/topic_list_order.dart';
import '../../forums/widgets/topic_compose_sheet.dart';
import '../utils/cuaresma_topic.dart';
import 'cuaresma_hub_design.dart';

const _defaultVisibleTopics = 4;

class CuaresmaTopicsPanel extends ConsumerStatefulWidget {
  const CuaresmaTopicsPanel({
    super.key,
    required this.forumId,
  });

  final String forumId;

  @override
  ConsumerState<CuaresmaTopicsPanel> createState() =>
      _CuaresmaTopicsPanelState();
}

class _CuaresmaTopicsPanelState extends ConsumerState<CuaresmaTopicsPanel> {
  var _showAll = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(forumTopicsRealtimeProvider(widget.forumId));
    final topicsAsync = ref.watch(forumTopicsProvider(widget.forumId));

    return topicsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => CuaresmaHubElevatedCard(
        child: Text(
          'No se pudieron cargar los temas.',
          style: TopicDetailTypography.meta(color: AppColors.textSecondary),
        ),
      ),
      data: (topics) {
        final community = cuaresmaCommunityTopics(topics);
        final visible = _showAll
            ? community
            : community.take(_defaultVisibleTopics).toList();
        final hasMore = community.length > _defaultVisibleTopics;

        return CuaresmaHubElevatedCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Temas',
                      style: TopicDetailTypography.body().copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (hasMore && !_showAll)
                    CuaresmaHubTextLink(
                      label: 'Ver todos',
                      onPressed: () => setState(() => _showAll = true),
                    ),
                ],
              ),
              if (community.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Aún no hay temas. Pulsa «+ Tema» para abrir el primero.',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                ...visible.map(
                  (topic) => _CuaresmaHubTopicRow(
                    topic: topic,
                    forumId: widget.forumId,
                    onTap: () async {
                      await context.push(
                        '/foros/${widget.forumId}/tema/${topic.id}',
                      );
                      if (context.mounted) {
                        ref.invalidate(forumTopicsProvider(widget.forumId));
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CuaresmaHubTopicRow extends StatelessWidget {
  const _CuaresmaHubTopicRow({
    required this.topic,
    required this.forumId,
    required this.onTap,
  });

  final ForumTopic topic;
  final String forumId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNew = isTopicNew(topic);
    final title = topic.excerpt.trim().isNotEmpty
        ? topic.excerpt.trim()
        : topic.title.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CofradeoAvatar(
                  imageUrl: topic.authorAvatarUrl,
                  icon: topic.avatarIcon,
                  size: 40,
                  backgroundColor: AppColors.backgroundElevated,
                ),
                if (isNew)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Nuevo',
                        style: TopicDetailTypography.meta(
                          color: AppColors.chipSelectedText,
                          fontWeight: FontWeight.w800,
                        ).copyWith(fontSize: 8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TopicDetailTypography.body().copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.authorHandle.startsWith('@')
                        ? topic.authorHandle
                        : '@${topic.authorHandle}',
                    style: TopicDetailTypography.meta(
                      color: AppColors.burgundy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _TopicCompactMeta(topic: topic),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicCompactMeta extends StatelessWidget {
  const _TopicCompactMeta({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final style = ForumTopicsTypography.card(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        const Icon(Icons.chat_bubble_outline, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text('${topic.commentCount}', style: style),
        const SizedBox(width: 10),
        const Icon(Icons.visibility_outlined, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(formatCount(topic.viewCount), style: style),
        const SizedBox(width: 10),
        Text(
          topic.timeAgo,
          style: style,
        ),
      ],
    );
  }
}

Future<void> openCuaresmaTopicCompose(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
}) {
  return showTopicComposeSheet(
    context,
    ref,
    forumId: forumId,
    seasonKey: cuaresmaSeasonKey,
  );
}
