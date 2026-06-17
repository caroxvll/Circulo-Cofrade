import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/calendar_quick_access_button.dart';
import '../../shared/models/forum.dart';
import '../auth/auth_provider.dart';
import 'data/mock_forums.dart';
import 'forums_provider.dart';
import '../profile/profile_provider.dart';
import 'utils/forum_navigation.dart';
import 'widgets/forum_last_activity_link.dart';
import 'widgets/topic_card.dart';
import 'widgets/topic_compose_sheet.dart';

class ForumTopicsScreen extends ConsumerWidget {
  const ForumTopicsScreen({
    super.key,
    required this.forumId,
  });

  final String forumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final isSuspended = ref.watch(isCurrentUserSuspendedProvider);
    final forum = ref.watch(forumPillarProvider(forumId)).asData?.value ??
        (supabaseReady ? null : forumById(forumId));
    final topicsAsync = ref.watch(forumTopicsProvider(forumId));
    if (forum == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foro')),
        body: const Center(child: Text('Foro no encontrado')),
      );
    }

    if (forum.isLocked) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => popForumTopicsList(context),
            icon: const Icon(Icons.chevron_left),
          ),
          title: Text(forum.name),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 48, color: AppColors.burgundy),
                const SizedBox(height: 16),
                Text(
                  forum.name,
                  style: AppTypography.displaySmall(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  forum.lockedLabel ?? 'Este foro estará disponible próximamente.',
                  style: AppTypography.bodyMedium(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isSuspended
          ? null
          : FloatingActionButton.extended(
        onPressed: () => showTopicComposeSheet(context, ref, forumId: forumId),
        backgroundColor: AppColors.burgundy,
        foregroundColor: AppColors.textOnDark,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo tema'),
      ),
      body: CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppColors.burgundyDark,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => popForumTopicsList(context),
            icon: const Icon(Icons.chevron_left, color: AppColors.gold),
          ),
            actions: const [
            CalendarQuickAccessButton(),
            SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF2A1515),
                        Color(0xFF1A0A0A),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 8, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: AppColors.burgundy,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                forum.headerIcon,
                                color: AppColors.gold,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    forum.name,
                                    style: AppTypography.displayMedium(
                                      color: AppColors.goldPale,
                                    ).copyWith(fontSize: 22),
                                  ),
                                  Text(
                                    forum.description,
                                    style: AppTypography.bodyMedium(
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formatForumStatsLine(forum),
                          style: AppTypography.labelSmall(
                            color: AppColors.accentRed,
                          ).copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        ForumLastActivityLink(
                          forum: forum,
                          onDarkBackground: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            height: 2,
            color: AppColors.burgundy,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Temas de Discusión',
              style: AppTypography.displaySmall(),
            ),
          ),
        ),
        if (supabaseReady)
          topicsAsync.when(
            loading: () => const SliverPadding(
              padding: EdgeInsets.all(32),
              sliver: SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'No se pudieron cargar los temas.',
                  style: AppTypography.bodyMedium(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (topics) => _topicsList(
              context,
              ref,
              topics: topics,
            ),
          )
        else
          _topicsList(
            context,
            ref,
            topics: topicsForForum(forumId),
          ),
      ],
      ),
    );
  }

  Widget _topicsList(
    BuildContext context,
    WidgetRef ref, {
    required List<ForumTopic> topics,
  }) {
    if (topics.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Aún no hay temas en este foro.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      sliver: SliverList.separated(
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final topic = topics[index];
          return TopicCard(
            topic: topic,
            onTap: () async {
              await context.push('/foros/$forumId/tema/${topic.id}');
              if (context.mounted) {
                ref.invalidate(forumTopicsProvider(forumId));
              }
            },
          );
        },
      ),
    );
  }
}
