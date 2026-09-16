import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import '../../core/widgets/cofradeo_error_panel.dart';
import '../../core/widgets/cofradeo_network_image.dart';
import '../../shared/models/forum.dart';
import 'forums_provider.dart';
import 'utils/forum_pillar_image_cache.dart';
import 'utils/topic_list_order.dart';
import 'widgets/forum_category_card.dart';
import 'widgets/forums_beige_background.dart';
import 'widgets/noticias_premium_banner.dart';
import 'forums_hero_tokens.dart';
import '../quiz/quiz_provider.dart';
import '../quiz/widgets/quiz_forums_card.dart';

class ForumsScreen extends ConsumerStatefulWidget {
  const ForumsScreen({super.key});

  @override
  ConsumerState<ForumsScreen> createState() => _ForumsScreenState();
}

class _ForumsScreenState extends ConsumerState<ForumsScreen> {
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

    final pillarsAsync = ref.watch(forumPillarsProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ForumsBeigeBackground(),
        pillarsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => CofradeoErrorPanel(
            message: 'No se pudieron cargar los foros.',
            subtitle: 'Comprueba tu conexión e inténtalo de nuevo.',
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
            final noticias = split.noticias;
            final forums = split.forums;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ForumsHero(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.burgundy,
                    onRefresh: () => _refreshForums(ref),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const sectionHeaderHeight = 36.0;
                        final noticiasBlock = noticias == null
                            ? 0.0
                            : NoticiasPremiumBanner.height + 8 + 12;
                        final forumsHeight = (constraints.maxHeight -
                                noticiasBlock -
                                sectionHeaderHeight)
                            .clamp(160.0, constraints.maxHeight);

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (noticias != null) ...[
                                  NoticiasPremiumBanner(
                                    forum: noticias,
                                    onTap: () => context.push(
                                      '/foros/${noticias.id}',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                                  child: SizedBox(
                                    height: sectionHeaderHeight,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _FeaturedSectionHeader(),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: forumsHeight,
                                  child: _ForumsCardsList(
                                    pillars: forums,
                                    listHeight: forumsHeight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (ref.watch(quizLiveVisibleProvider).asData?.value ?? true)
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

class _ForumsCardsList extends StatelessWidget {
  const _ForumsCardsList({
    required this.pillars,
    required this.listHeight,
  });

  final List<ForumCategory> pillars;
  final double listHeight;

  @override
  Widget build(BuildContext context) {
    if (pillars.isEmpty) return const SizedBox.shrink();

    final gaps = (pillars.length - 1) * ForumCategoryCard.cardGap;
    final cardHeight = (listHeight - gaps - 12) / pillars.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        children: [
          for (var i = 0; i < pillars.length; i++) ...[
            if (i > 0) const SizedBox(height: ForumCategoryCard.cardGap),
            SizedBox(
              height: cardHeight,
              child: ForumCategoryCard(
                forum: pillars[i],
                height: cardHeight,
                onTap: () => context.push('/foros/${pillars[i].id}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedSectionHeader extends StatelessWidget {
  const _FeaturedSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foros destacados',
          style: AppTypography.displaySmall(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 18, letterSpacing: 0.08),
        ),
        const SizedBox(height: 6),
        Container(
          width: 44,
          height: 1.5,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _ForumsHero extends ConsumerWidget {
  const _ForumsHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroUrl = ref.watch(forumsListHeroImageProvider).asData?.value;
    final screenW = MediaQuery.sizeOf(context).width;
    final heroCache = ImageDecodeCache.px(context, screenW);
    final heroAsset = Image.asset(
      AppAssets.heroProcesion,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.45),
      filterQuality: FilterQuality.medium,
      cacheWidth: heroCache,
      gaplessPlayback: true,
    );

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: heroUrl != null && heroUrl.isNotEmpty
                ? CofradeoNetworkImage(
                    url: heroUrl,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.45),
                    cacheSize: screenW,
                    filterQuality: FilterQuality.medium,
                    placeholder: heroAsset,
                    errorWidget: heroAsset,
                  )
                : heroAsset,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: ForumsHeroTokens.gradientOverlay(),
              ),
            ),
          ),
          Padding(
            padding: ForumsHeroTokens.contentPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOROS',
                  style: ForumsHeroTokens.heroTitleStyle(),
                ),
                const SizedBox(height: ForumsHeroTokens.afterTitleGap),
                Text(
                  'Participa en la mayor\ncomunidad cofrade',
                  style: ForumsHeroTokens.heroSubtitleStyle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
