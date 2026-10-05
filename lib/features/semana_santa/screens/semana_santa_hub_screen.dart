import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../../auth/auth_provider.dart';
import '../../forums/forums_provider.dart';
import '../../forums/mis_hermandades_provider.dart';
import '../../forums/utils/forum_navigation.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';
import '../utils/semana_santa_topic.dart';
import '../widgets/ss_hub_header.dart';
import '../widgets/ss_hub_hermandades_strip.dart';
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
      ref.watch(ssLiveRealtimeProvider);
    }

    return topicAsync.when(
      skipLoadingOnReload: true,
      loading: () => const HubScreenSkeleton(),
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
        final liveOpen = gate?.isOpen == true;
        final canInform =
            liveOpen && (ref.watch(ssCanInformProvider).asData?.value ?? false);

        Future<void> refresh() async {
          await Future.wait([
            ref.read(ssLiveRawFeedProvider.notifier).reload(),
            ref.read(ssLiveGateProvider.future),
          ]);
          ref.invalidate(ssLiveGateProvider);
          await ref.read(ssLiveEngagementProvider.notifier).reload();
          ref.invalidate(forumTopicProvider(topicKey));
          ref.invalidate(forumTopicsProvider(forumId));
          ref.invalidate(followedHermandadBoardsProvider);
        }

        void openInformar({SsLiveUpdateKind? seedKind}) {
          if (seedKind != null) {
            context.push(
              '/foros/$forumId/tema/$topicId/informar/${seedKind.dbValue}',
            );
            return;
          }
          context.push('/foros/$forumId/tema/$topicId/informar');
        }

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
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Semana Santa',
                  style: AppTypography.displaySmall(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.05),
                ),
                Text(
                  'Sevilla',
                  style: AppTypography.labelSmall(
                    color: AppColors.burgundy,
                  ).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Temas',
                onPressed: () => _openTopicsSheet(
                  context,
                  ref,
                  forumId: forumId,
                ),
                icon: Badge(
                  isLabelVisible: topicsCount > 0,
                  label: Text('$topicsCount'),
                  backgroundColor: AppColors.burgundy,
                  child: const Icon(
                    Icons.forum_outlined,
                    color: AppColors.burgundy,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SemanaSantaHubSummaryCard(
                  liveUpdateCount: stats.total,
                  topicsCount: topicsCount,
                  liveOpen: liveOpen,
                  canInform: canInform,
                  jornadaLabel: gate?.activeDay?.label,
                  onPublish: openInformar,
                  onNewTopic: () => openSemanaSantaTopicCompose(
                    context,
                    ref,
                    forumId: forumId,
                  ),
                ),
                const SizedBox(height: 10),
                const SemanaSantaHubHermandadesStrip(),
                const SizedBox(height: 10),
                Expanded(
                  child: SemanaSantaRadarSection(
                    forumId: forumId,
                    topicId: topicId,
                    fillHeight: true,
                    onRefresh: refresh,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTopicsSheet(
    BuildContext context,
    WidgetRef ref, {
    required String forumId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.82;
        return SizedBox(
          height: maxH,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Temas · Semana Santa',
                        style: AppTypography.displaySmall().copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        openSemanaSantaTopicCompose(
                          context,
                          ref,
                          forumId: forumId,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nuevo'),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SemanaSantaTopicsPanel(forumId: forumId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
