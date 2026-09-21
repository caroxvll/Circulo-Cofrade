import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/forum_text_format.dart';
import '../../core/widgets/cofradeo_error_panel.dart';
import '../../core/widgets/cofradeo_network_image.dart';
import '../../shared/models/followed_topic.dart';
import '../search/follows_provider.dart';
import 'mis_hermandades_provider.dart';
import 'utils/hermandad_board_display.dart';
import 'utils/hermandad_local_assets.dart';
import 'utils/official_post_categories.dart';
import 'widgets/forums_beige_background.dart';

class MisHermandadesScreen extends ConsumerStatefulWidget {
  const MisHermandadesScreen({super.key});

  @override
  ConsumerState<MisHermandadesScreen> createState() =>
      _MisHermandadesScreenState();
}

class _MisHermandadesScreenState extends ConsumerState<MisHermandadesScreen> {
  @override
  void initState() {
    super.initState();
    HermandadLocalAssets.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final boardsAsync = ref.watch(followedHermandadBoardsProvider);
    final feedAsync = ref.watch(followedHermandadFeedProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ForumsBeigeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: AppColors.background.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Tus Hermandades',
              style: AppTypography.displaySmall(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 20),
            ),
            actions: [
              TextButton(
                onPressed: () => context.push('/foros/hermandades'),
                child: const Text('Directorio'),
              ),
            ],
          ),
          body: boardsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => CofradeoErrorPanel(
              message: 'No se pudieron cargar tus hermandades.',
              onRetry: () {
                ref.invalidate(followedTopicsDetailsProvider);
                ref.invalidate(followedHermandadFeedProvider);
              },
            ),
            data: (boards) {
              if (boards.isEmpty) {
                return const _EmptyState();
              }
              return RefreshIndicator(
                color: AppColors.burgundy,
                onRefresh: () async {
                  ref.invalidate(followedTopicsDetailsProvider);
                  ref.invalidate(followedHermandadFeedProvider);
                  await ref.read(followedHermandadFeedProvider.future);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _BoardsHeader(boards: boards),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                        child: Text(
                          'Actividad reciente',
                          style: AppTypography.displaySmall(
                            color: AppColors.textPrimary,
                          ).copyWith(fontSize: 16, letterSpacing: 0.04),
                        ),
                      ),
                    ),
                    feedAsync.when(
                      loading: () => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => SliverFillRemaining(
                        hasScrollBody: false,
                        child: CofradeoErrorPanel(
                          message: 'No se pudo cargar la actividad.',
                          onRetry: () =>
                              ref.invalidate(followedHermandadFeedProvider),
                        ),
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _FeedEmpty(),
                          );
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          sliver: SliverList.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _FeedCard(item: items[index]);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BoardsHeader extends StatelessWidget {
  const _BoardsHeader({required this.boards});

  final List<FollowedTopic> boards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            boards.length == 1
                ? 'Tu espacio con ${parseHermandadTopicTitle(boards.first.title).hermandadName}'
                : 'Las ${boards.length} que sigues',
            style: AppTypography.bodyMedium(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13.5, height: 1.35),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: boards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final board = boards[index];
              final parsed = parseHermandadTopicTitle(board.title);
              return _BoardTile(
                name: parsed.hermandadName,
                day: parsed.processionDay,
                onTap: () => context.push(
                  '/foros/${board.forumId}/tema/${board.topicId}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({
    required this.name,
    required this.day,
    required this.onTap,
  });

  final String name;
  final String? day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = hermandadDayAccentColor(day);
    final avatar = HermandadLocalAssets.avatar(
      processionDay: day,
      hermandadName: name,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 132,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.1),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.45),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatar != null
                        ? Image.asset(avatar, fit: BoxFit.cover)
                        : Icon(
                            Icons.church_outlined,
                            size: 17,
                            color: accent,
                          ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(
                  color: AppColors.textPrimary,
                ).copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final HermandadFeedItem item;

  @override
  Widget build(BuildContext context) {
    final reply = item.reply;
    final category = reply.officialCategory ?? 'noticia';
    final excerpt = plainTextForExcerpt(reply.content, maxLength: 140);
    final accent = hermandadDayAccentColor(item.processionDay);
    final imageUrl = reply.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          '/foros/${item.board.forumId}/tema/${item.board.topicId}'
          '?reply=${reply.id}',
        ),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundyDark.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3.5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.hermandadName,
                                style: AppTypography.titleLarge().copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              reply.timeAgo,
                              style: AppTypography.bodyMedium(
                                color: AppColors.textMuted,
                              ).copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.burgundy.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            officialCategoryLabel(category),
                            style: AppTypography.bodyMedium(
                              color: AppColors.burgundy,
                            ).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (excerpt.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            excerpt,
                            style: AppTypography.bodyMedium(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 13, height: 1.35),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (hasImage) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: CofradeoNetworkImage(
                                url: imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.burgundy.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.church_outlined,
                size: 32,
                color: AppColors.burgundy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no sigues ninguna',
              textAlign: TextAlign.center,
              style: AppTypography.displaySmall(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige la tuya en el directorio y tendrás aquí '
              'cultos, igualás y avisos sin salir de Cofradeo.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context.push('/foros/hermandades'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              child: const Text('Elegir mi hermandad'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 36,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay publicaciones',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge().copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando publiquen en su tablón, aparecerán aquí.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 13.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
