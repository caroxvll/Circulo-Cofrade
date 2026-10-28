import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import '../../core/widgets/cofradeo_asset_image.dart';
import '../../core/widgets/cofradeo_error_panel.dart';
import '../../core/widgets/cofradeo_network_image.dart';
import '../../core/widgets/cofradeo_skeleton.dart';
import '../../shared/models/forum.dart';
import '../semana_santa/widgets/ss_forums_live_chip.dart';
import 'forums_provider.dart';
import 'utils/forum_navigation.dart';
import 'utils/forum_pillar_image_cache.dart';
import 'utils/hermandad_local_assets.dart';
import 'utils/topic_list_order.dart';
import 'widgets/forum_category_card.dart';
import 'widgets/forums_beige_background.dart';
import 'forums_hero_tokens.dart';
import '../quiz/quiz_provider.dart';
import '../quiz/widgets/quiz_forums_card.dart';
import '../../core/widgets/search_quick_access_button.dart';

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

            final forums = splitNoticiasFromForums(visible).forums;

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
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: _FilledForumsBlock(pillars: forums),
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

/// Lista de foros. Con anuncio el alto ya viene justo. Sin anuncio las
/// fichas crecen un poco para no dejar un hueco beige abajo, con tope:
/// el bloque AHORA sigue ceñido al texto.
class _FilledForumsBlock extends StatelessWidget {
  const _FilledForumsBlock({required this.pillars});

  final List<ForumCategory> pillars;

  static const _sectionHeaderHeight = 26.0;
  static const _afterHeaderGap = 8.0;
  /// Aire entre el hero y «Foros destacados».
  static const _topInset = 14.0;
  static const _bottomInset = 2.0;
  static const _minCard = 112.0;
  /// Alto en el que título, descripción y AHORA llenan la ficha.
  static const _snugCard = 168.0;
  /// Tope si sobra pantalla (sin anuncio). Por encima no se estira más.
  static const _maxCard = 208.0;
  static const _maxGap = 14.0;
  static const _maxBottomInset = 16.0;
  static const _sidePad = 14.0;

  @override
  Widget build(BuildContext context) {
    if (pillars.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final n = pillars.length;
        final gapCount = n - 1;
        final minGap = ForumCategoryCard.cardGap;
        final chrome = _topInset + _sectionHeaderHeight + _afterHeaderGap;
        final available = (constraints.maxHeight - chrome)
            .clamp(0.0, constraints.maxHeight);

        final snug =
            n * _snugCard + gapCount * minGap + _bottomInset;
        final gapBudget = gapCount * (_maxGap - minGap);
        final bottomBudget = _maxBottomInset - _bottomInset;
        final cardBudget = n * (_maxCard - _snugCard);

        late final double cardHeight;
        late final double gap;
        late final double bottom;

        if (available <= snug) {
          final room =
              (available - gapCount * minGap - _bottomInset).clamp(0.0, available);
          final raw = room / n;
          final upper = raw < _minCard ? _minCard : raw;
          cardHeight = raw.floorToDouble().clamp(_minCard, upper);
          gap = minGap;
          bottom = _bottomInset;
        } else {
          var extra = available - snug;
          final cardTake = extra < cardBudget ? extra : cardBudget;
          extra -= cardTake;
          final gapTake = extra < gapBudget ? extra : gapBudget;
          extra -= gapTake;
          final bottomTake = extra < bottomBudget ? extra : bottomBudget;

          cardHeight = (_snugCard + cardTake / n).floorToDouble();
          gap = gapCount == 0 ? 0 : minGap + gapTake / gapCount;
          bottom = _bottomInset + bottomTake;
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            _sidePad,
            _topInset,
            _sidePad,
            bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: _sectionHeaderHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _FeaturedSectionHeader(),
                ),
              ),
              const SizedBox(height: _afterHeaderGap),
              for (var i = 0; i < n; i++) ...[
                if (i > 0) SizedBox(height: gap),
                SizedBox(
                  height: cardHeight,
                  child: _ForumCard(
                    forum: pillars[i],
                    height: cardHeight,
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

class _ForumCard extends ConsumerWidget {
  const _ForumCard({required this.forum, required this.height});

  final ForumCategory forum;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ForumCategoryCard(
      forum: forum,
      height: height,
      onTap: () => pushForumTopicsList(
        context,
        ref,
        forumId: forum.id,
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
          ).copyWith(fontSize: 17, letterSpacing: 0.08),
        ),
        const SizedBox(height: 3),
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
    final heroAsset = CofradeoAssetImage(
      assetPath: AppAssets.heroProcesion,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.45),
      filterQuality: FilterQuality.medium,
      cacheWidth: heroCache,
      fadeDuration: const Duration(milliseconds: 320),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FOROS',
                            style: ForumsHeroTokens.heroTitleStyle().copyWith(
                              fontSize: 28,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            width: 28,
                            height: 1.5,
                            color: AppColors.gold.withValues(alpha: 0.75),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'COMUNIDAD COFRADE',
                            style: AppTypography.labelSmall(
                              color: AppColors.goldPale.withValues(alpha: 0.92),
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              letterSpacing: 1.6,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SemanaSantaForumsLiveChip(inline: true),
                          SizedBox(width: 4),
                          SearchQuickAccessButton(iconColor: AppColors.gold),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Participa en la mayor comunidad cofrade',
                  style: ForumsHeroTokens.heroSubtitleStyle().copyWith(
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
