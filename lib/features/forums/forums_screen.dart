import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/cofradeo_error_panel.dart';
import '../../core/widgets/cofradeo_skeleton.dart';
import '../permissions/permissions_provider.dart';
import '../profile/profile_provider.dart';
import 'forums_provider.dart';
import 'utils/forum_pillar_image_cache.dart';
import 'utils/hermandad_local_assets.dart';
import 'utils/topic_list_order.dart';
import 'topic_detail_screen.dart';
import 'widgets/comunidad_home.dart';
import 'widgets/forums_beige_background.dart';
import '../quiz/quiz_provider.dart';
import '../quiz/widgets/quiz_forums_card.dart';

class ForumsScreen extends ConsumerStatefulWidget {
  const ForumsScreen({super.key});

  @override
  ConsumerState<ForumsScreen> createState() => _ForumsScreenState();
}

class _ForumsScreenState extends ConsumerState<ForumsScreen> {
  @override
  void initState() {
    super.initState();
    // Calentar escudos/fondos locales antes de abrir Hermandades.
    if (!HermandadLocalAssets.isReady) {
      HermandadLocalAssets.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(forumPillarsProvider, (previous, next) {
      next.whenData((pillars) {
        final heroUrl = ref.read(forumsListHeroImageProvider).asData?.value;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          precacheForumPillarImages(
            context,
            visibleForumPillars(pillars),
            heroUrl: heroUrl,
          );
        });
      });
    });

    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final topicIds = ref.watch(hermandadTopicIdsProvider).asData?.value;
    final officialHermandad =
        profile?.accountType.isBrotherhood == true && profile?.isSuspended != true;
    if (officialHermandad && topicIds == null) {
      return const Stack(
        fit: StackFit.expand,
        children: [
          ForumsBeigeBackground(),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (officialHermandad && topicIds!.isNotEmpty) {
      return TopicDetailScreen(
        forumId: 'hermandades',
        topicId: topicIds.first,
        embedded: true,
      );
    }

    final pillarsAsync = ref.watch(forumPillarsProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ForumsBeigeBackground(),
        pillarsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ForumsHomeSkeleton(),
          error: (_, _) => CofradeoErrorPanel(
            message: 'No se pudieron cargar los foros.',
            subtitle: 'Comprueba tu conexiÃ³n e intÃ©ntalo de nuevo.',
            onRetry: () => invalidateForumPillarData(ref),
          ),
          data: (pillars) {
            final visible = visibleForumPillars(pillars);
            if (visible.isEmpty) {
              return const CofradeoErrorPanel(
                message: 'No hay foros disponibles.',
                icon: Icons.forum_outlined,
              );
            }

            final split = splitNoticiasFromForums(visible);
            final forums = split.forums;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.burgundy,
                    onRefresh: () => _refreshForums(ref),
                    child: ComunidadHome(
                      forums: forums,
                      noticias: split.noticias,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (ref.watch(quizLiveVisibleProvider).asData?.value == true)
          const QuizForumsFab(),
      ],
    );
  }

  Future<void> _refreshForums(WidgetRef ref) async {
    invalidateForumPillarData(ref);
    final pillars = await ref.read(forumPillarsProvider.future);
    final heroUrl = await ref.read(forumsListHeroImageProvider.future);
    if (!mounted) return;
    await precacheForumPillarImages(
      context,
      visibleForumPillars(pillars),
      heroUrl: heroUrl,
    );
  }
}
