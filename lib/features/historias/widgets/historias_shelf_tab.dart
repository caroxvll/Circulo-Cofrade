import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../historias_provider.dart';
import '../models/historia.dart';
import 'historia_compose_sheet.dart';

class HistoriasShelfTab extends ConsumerWidget {
  const HistoriasShelfTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(publishedHistoriasProvider);
    final canPublish = ref.watch(canPublishHistoriasProvider);

    return books.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudieron cargar las historias.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (items) {
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(publishedHistoriasProvider);
                await ref.read(publishedHistoriasProvider.future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: _ShelfIntro()),
                  if (items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyShelf(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.62,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _BookCover(historia: items[index]),
                          childCount: items.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (canPublish)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final created = await showHistoriaComposeSheet(context);
                    if (created) {
                      ref.invalidate(publishedHistoriasProvider);
                    }
                  },
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Escribir'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShelfIntro extends StatelessWidget {
  const _ShelfIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Historias', style: AppTypography.displaySmall()),
          const SizedBox(height: 4),
          Text(
            'Libros, crónicas y anécdotas. Ábrelos y pásalos página a página.',
            style: AppTypography.bodyMedium(),
          ),
        ],
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: AppColors.goldDark.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'La estantería está vacía',
            style: AppTypography.titleLarge(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando un cronista publique un libro, una crónica o una anécdota, aparecerá aquí.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.historia});

  final Historia historia;

  @override
  Widget build(BuildContext context) {
    final cover = historia.coverImageUrl?.trim();
    return InkWell(
      onTap: () => context.push('/historias/${historia.id}'),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.burgundyDark.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(3, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null && cover.isNotEmpty)
                      CofradeoNetworkImage(url: cover, fit: BoxFit.cover)
                    else
                      const ColoredBox(color: Color(0xFF3A1A16)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x33000000),
                            Color(0xCC2A0F0C),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            historia.kind.label.toUpperCase(),
                            style: AppTypography.labelSmall(
                              color: AppColors.gold,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            historia.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.hermandadName(
                              color: AppColors.textOnDark,
                            ).copyWith(fontSize: 16, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            historia.authorDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall(color: AppColors.goldDark)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${historia.pageCount} pág. · ${historia.commentCount} comentarios',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall(),
          ),
        ],
      ),
    );
  }
}
