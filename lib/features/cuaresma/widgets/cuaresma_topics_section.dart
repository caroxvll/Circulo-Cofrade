import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
import '../../../core/widgets/cofradeo_skeleton.dart';

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
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: HubSectionListSkeleton(),
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Temas',
                      style: AppTypography.hermandadName(
                        color: AppColors.textPrimary,
                      ).copyWith(fontSize: 22, height: 1),
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
                const SizedBox(height: 6),
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.gold.withValues(alpha: 0.22),
                    ),
                  Builder(
                    builder: (context) {
                      final topic = visible[i];
                      return _CuaresmaHubTopicRow(
                        topic: topic,
                        onTap: () async {
                          await context.push(
                            '/foros/${widget.forumId}/tema/${topic.id}',
                          );
                          if (context.mounted) {
                            ref.invalidate(forumTopicsProvider(widget.forumId));
                          }
                        },
                      );
                    },
                  ),
                ],
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
    required this.onTap,
  });

  final ForumTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNew = isTopicNew(topic);
    final title = topic.title.trim().isNotEmpty
        ? topic.title.trim()
        : topic.excerpt.trim();
    final handle = topic.authorHandle.startsWith('@')
        ? topic.authorHandle
        : '@${topic.authorHandle}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TopicDetailTypography.meta(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ).copyWith(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        topic.timeAgo,
                        style: TopicDetailTypography.meta(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTypography.newsHeadline().copyWith(
                      fontSize: 18.5,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _TopicCompactMeta(topic: topic, isNew: isNew),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicCompactMeta extends StatelessWidget {
  const _TopicCompactMeta({
    required this.topic,
    required this.isNew,
  });

  final ForumTopic topic;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final style = ForumTopicsTypography.card(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        const Icon(
          Icons.chat_bubble_outline,
          size: 13,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Text('${topic.commentCount}', style: style),
        const SizedBox(width: 12),
        const Icon(
          Icons.visibility_outlined,
          size: 13,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Text(formatCount(topic.viewCount), style: style),
        const Spacer(),
        if (isNew)
          Text(
            'Nuevo',
            style: TopicDetailTypography.meta(
              color: AppColors.burgundy,
              fontWeight: FontWeight.w700,
            ).copyWith(fontSize: 12),
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
