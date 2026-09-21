import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/followed_topic.dart';
import '../mis_hermandades_provider.dart';
import '../utils/hermandad_board_display.dart';
import '../utils/hermandad_local_assets.dart';

/// Bloque compacto en la home de Foros → «Tus Hermandades».
class MisHermandadesHomeStrip extends ConsumerWidget {
  const MisHermandadesHomeStrip({super.key});

  /// Altura reservada cuando hay seguidas (header + chips).
  static const heightFollowing = 124.0;

  /// Altura del CTA vacío / sin sesión.
  static const heightEmpty = 86.0;

  static double heightFor(AsyncValue<List<FollowedTopic>> boards) {
    final list = boards.asData?.value;
    if (list != null && list.isNotEmpty) return heightFollowing;
    return heightEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(followedHermandadBoardsProvider);

    return boardsAsync.when(
      loading: () => const SizedBox(height: heightEmpty),
      error: (_, _) => _EmptyStrip(
        onExplore: () => context.push('/foros/hermandades'),
      ),
      data: (boards) {
        if (boards.isEmpty) {
          return _EmptyStrip(
            onExplore: () => context.push('/foros/hermandades'),
          );
        }
        return _FollowingStrip(boards: boards);
      },
    );
  }
}

class _FollowingStrip extends StatelessWidget {
  const _FollowingStrip({required this.boards});

  final List<FollowedTopic> boards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tus Hermandades',
                        style: AppTypography.displaySmall(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 17, letterSpacing: 0.06),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        boards.length == 1
                            ? 'Lo que publica la tuya'
                            : 'Lo que publican las tuyas',
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/foros/mis-hermandades'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Ver todo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: boards.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == boards.length) {
                  return _AddChip(
                    onTap: () => context.push('/foros/hermandades'),
                  );
                }
                final board = boards[index];
                return _HermandadChip(
                  board: board,
                  onTap: () => context.push(
                    '/foros/${board.forumId}/tema/${board.topicId}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onExplore,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.burgundy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.church_outlined,
                    color: AppColors.burgundy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tus Hermandades',
                        style: AppTypography.titleLarge().copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sigue la tuya y ten aquí todo lo que publica.',
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HermandadChip extends StatelessWidget {
  const _HermandadChip({required this.board, required this.onTap});

  final FollowedTopic board;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = parseHermandadTopicTitle(board.title);
    final name = parsed.hermandadName;
    final accent = hermandadDayAccentColor(parsed.processionDay);
    final avatar = HermandadLocalAssets.avatar(
      processionDay: parsed.processionDay,
      hermandadName: name,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 118,
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar != null
                    ? Image.asset(avatar, fit: BoxFit.cover)
                    : Icon(Icons.church_outlined, size: 18, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(
                    color: AppColors.textPrimary,
                  ).copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border,
              style: BorderStyle.solid,
            ),
            color: AppColors.surfaceAlt,
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.burgundy, size: 22),
              SizedBox(height: 2),
              Text(
                'Seguir',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
