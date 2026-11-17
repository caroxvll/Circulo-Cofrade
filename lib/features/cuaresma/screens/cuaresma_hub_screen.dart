import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';
import '../../ads/widgets/sponsored_placement_slot.dart';
import '../../auth/auth_provider.dart';
import '../../forums/data/mock_forums.dart';
import '../../forums/forums_provider.dart';
import '../../forums/utils/forum_navigation.dart';
import '../../forums/widgets/forum_editorial_title.dart';
import '../cuaresma_ensayos_provider.dart';
import '../utils/cuaresma_topic.dart';
import '../utils/ensayos_day_groups.dart';
import '../widgets/cuaresma_hub_header.dart';
import '../widgets/cuaresma_hub_live_section.dart';
import '../widgets/cuaresma_topics_section.dart';

class CuaresmaHubScreen extends ConsumerWidget {
  const CuaresmaHubScreen({
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
    final agendaAsync = ref.watch(todayCuaresmaAgendaProvider);
    final topicsAsync = ref.watch(forumTopicsProvider(forumId));
    if (supabaseReady) {
      ref.watch(forumTopicsRealtimeProvider(forumId));
      ref.watch(topicThreadRealtimeProvider(topicKey));
    }
    final forumName = ref.watch(forumPillarProvider(forumId)).asData?.value?.name ??
        (supabaseReady ? 'Foro' : forumById(forumId)?.name ?? 'Foro');

    return topicAsync.when(
      skipLoadingOnReload: true,
      loading: () => const HubScreenSkeleton(),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Cuaresma')),
        body: const Center(child: Text('No se pudo cargar el espacio')),
      ),
      data: (topic) {
        if (topic == null || !isCuaresmaTopic(topic)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cuaresma')),
            body: const Center(child: Text('Tema no encontrado')),
          );
        }

        final agenda = agendaAsync.asData?.value ?? const [];
        final groups = groupTodayEnsayos(agenda);
        final topicsCount =
            cuaresmaCommunityTopics(topicsAsync.asData?.value ?? const []).length;
        final focusEventId = GoRouterState.of(context).uri.queryParameters['cita'];

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
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CuaresmaHubHeroStack(
                agendaLabel: cuaresmaHubAgendaLabel(
                  agenda,
                  liveCount: groups.live.length,
                ),
                agendaLive: groups.live.isNotEmpty,
                topicsCount: topicsCount,
                onNewTopic: () => openCuaresmaTopicCompose(
                  context,
                  ref,
                  forumId: forumId,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SponsoredPlacementSlot(
                  placement: AdPlacement.featuredTopic,
                  topicId: topicId,
                  style: SponsoredAdCardStyle.banner,
                  compact: true,
                  sectionLabel: 'Publicidad',
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.burgundy,
                  onRefresh: () async {
                    ref.invalidate(forumTopicProvider(topicKey));
                    ref.invalidate(todayCuaresmaAgendaProvider);
                    ref.invalidate(todayEnsayosProvider);
                    ref.invalidate(forumTopicsProvider(forumId));
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      cofradeoBottomScrollPadding(context) + 20,
                    ),
                    children: [
                      CuaresmaHubLiveSection(
                        forumId: forumId,
                        topicId: topicId,
                        focusEventId: focusEventId,
                      ),
                      const SizedBox(height: 12),
                      CuaresmaTopicsPanel(forumId: forumId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
