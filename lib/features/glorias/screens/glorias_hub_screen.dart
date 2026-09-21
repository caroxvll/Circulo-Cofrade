import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';
import '../../ads/widgets/sponsored_placement_slot.dart';
import '../../auth/auth_provider.dart';
import '../../forums/data/mock_forums.dart';
import '../../forums/forums_provider.dart';
import '../../forums/utils/forum_navigation.dart';
import '../../forums/widgets/forum_editorial_title.dart';
import '../glorias_provider.dart';
import '../utils/glorias_topic.dart';
import '../widgets/glorias_agenda_section.dart';
import '../widgets/glorias_hub_header.dart';
import '../widgets/glorias_topics_section.dart';

class GloriasHubScreen extends ConsumerWidget {
  const GloriasHubScreen({
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
    final agendaAsync = ref.watch(gloriasUpcomingEventsProvider);
    final topicsAsync = ref.watch(forumTopicsProvider(forumId));
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
        appBar: AppBar(title: const Text('Glorias')),
        body: const Center(child: Text('No se pudo cargar el espacio')),
      ),
      data: (topic) {
        if (topic == null || !isGloriasTopic(topic)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Glorias')),
            body: const Center(child: Text('Tema no encontrado')),
          );
        }

        final upcomingCount = agendaAsync.asData?.value.length ?? 0;
        final topicsCount =
            gloriasCommunityTopics(topicsAsync.asData?.value ?? const []).length;

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
            title: ForumEditorialTitle(
              title: forumName,
              forumId: forumId,
            ),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            color: AppColors.burgundy,
            onRefresh: () async {
              ref.invalidate(forumTopicProvider(topicKey));
              ref.invalidate(gloriasUpcomingEventsProvider);
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
                GloriasHubHeroStack(
                  topic: topic,
                  upcomingCount: upcomingCount,
                  topicsCount: topicsCount,
                  onNewTopic: () => openGloriasTopicCompose(
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
                      const GloriasAgendaPanel(),
                      const SizedBox(height: 12),
                      GloriasTopicsPanel(forumId: forumId),
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
