import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';
import '../../ads/widgets/sponsored_placement_slot.dart';
import '../../auth/auth_provider.dart';
import '../../forums/data/mock_forums.dart';
import '../../forums/forums_provider.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/utils/forum_navigation.dart';
import '../semana_santa_provider.dart';
import '../utils/semana_santa_topic.dart';
import '../widgets/ss_hub_header.dart';
import '../widgets/ss_radar_section.dart';
import '../widgets/ss_topics_section.dart';

class SemanaSantaHubScreen extends ConsumerWidget {
  const SemanaSantaHubScreen({
    super.key,
    required this.forumId,
    required this.topicId,
  });

  final String forumId;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final topicKey = ForumTopicKey(forumId: forumId, topicId: topicId);
    ref.watch(topicViewTrackerProvider(topicKey));

    final topicAsync = ref.watch(forumTopicProvider(topicKey));
    final stats = ref.watch(ssLiveStatsProvider);
    final topicsAsync = ref.watch(forumTopicsProvider(forumId));
    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    if (supabaseReady) {
      ref.watch(forumTopicsRealtimeProvider(forumId));
      ref.watch(topicThreadRealtimeProvider(topicKey));
    }
    final forumName = ref.watch(forumPillarProvider(forumId)).asData?.value?.name ??
        (supabaseReady ? 'Foro' : forumById(forumId)?.name ?? 'Foro');

    return topicAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Semana Santa')),
        body: const Center(child: Text('No se pudo cargar el espacio')),
      ),
      data: (topic) {
        if (topic == null || !isSemanaSantaTopic(topic)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Semana Santa')),
            body: const Center(child: Text('Tema no encontrado')),
          );
        }

        final topicsCount = semanaSantaCommunityTopics(
          topicsAsync.asData?.value ?? const [],
        ).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => popForumTopic(context, forumId: forumId),
              icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
            ),
            title: Text(
              forumName,
              style: TopicDetailTypography.appBarTitle(),
            ),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            color: AppColors.burgundy,
            onRefresh: () async {
              ref.invalidate(forumTopicProvider(topicKey));
              ref.invalidate(ssLiveRawFeedProvider);
              ref.invalidate(ssLiveGateProvider);
              ref.invalidate(forumTopicsProvider(forumId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.only(
                bottom: cofradeoBottomScrollPadding(context) + 20,
              ),
              children: [
                SemanaSantaHubHeroStack(
                  topic: topic,
                  liveUpdateCount: stats.total,
                  topicsCount: topicsCount,
                  liveOpen: gate?.isOpen ?? true,
                  jornadaLabel: gate?.activeDay?.label,
                  onPublish: () => context.push(
                    '/foros/$forumId/tema/$topicId/en-directo',
                  ),
                  onNewTopic: () => openSemanaSantaTopicCompose(
                    context,
                    ref,
                    forumId: forumId,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SponsoredPlacementSlot(
                    placement: AdPlacement.featuredTopic,
                    topicId: topicId,
                    style: SponsoredAdCardStyle.banner,
                    compact: true,
                    sectionLabel: 'Publicidad',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      SemanaSantaRadarSection(
                        forumId: forumId,
                        topicId: topicId,
                      ),
                      const SizedBox(height: 22),
                      SemanaSantaTopicsPanel(forumId: forumId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
