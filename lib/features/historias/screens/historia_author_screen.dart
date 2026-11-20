import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/chronicler_badge.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../auth/auth_provider.dart';
import '../historias_provider.dart';
import '../widgets/historia_cover_card.dart';
import '../widgets/historia_follow_button.dart';

class HistoriaAuthorScreen extends ConsumerWidget {
  const HistoriaAuthorScreen({super.key, required this.authorId});

  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(publishedHistoriasByAuthorProvider(authorId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.burgundyDark,
        elevation: 0,
        title: books.maybeWhen(
          data: (items) => Text(
            items.isEmpty ? 'Cronista' : items.first.authorDisplayName,
            style: AppTypography.hermandadName().copyWith(fontSize: 18),
          ),
          orElse: () => Text(
            'Cronista',
            style: AppTypography.hermandadName().copyWith(fontSize: 18),
          ),
        ),
      ),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'No se pudo abrir esta estantería.',
            style: AppTypography.bodyMedium(),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Este cronista aún no ha publicado.',
                style: AppTypography.bodyMedium(),
              ),
            );
          }
          final author = items.first;
          return LayoutBuilder(
            builder: (context, constraints) {
              return CustomScrollView(
                slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    children: [
                      CofradeoAvatar(
                        imageUrl: author.authorAvatarUrl,
                        size: 72,
                        backgroundColor: AppColors.backgroundElevated,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              author.authorDisplayName,
                              textAlign: TextAlign.center,
                              style: AppTypography.displaySmall(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const ChroniclerIcon(size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cronista',
                        style: AppTypography.labelSmall(color: AppColors.goldDark)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${author.atHandle} · ${items.length} '
                        '${items.length == 1 ? 'obra' : 'obras'}',
                        style: AppTypography.bodyMedium(),
                      ),
                      if (ref.watch(currentUserProvider)?.id !=
                          author.authorId) ...[
                        const SizedBox(height: 14),
                        HistoriaFollowButton(authorId: author.authorId),
                        const SizedBox(height: 6),
                        Text(
                          'Si le sigues, sus obras salen primero en El Cronicón.',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Text(
                    'En El Cronicón',
                    style: AppTypography.sectionTitle(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverGrid(
                  gridDelegate: HistoriaCoverCard.gridDelegateFor(
                    constraints.maxWidth,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => HistoriaCoverCard(
                      historia: items[index],
                      showAuthor: false,
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
