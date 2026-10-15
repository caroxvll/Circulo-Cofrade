import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../search/follows_provider.dart';
import '../forum_topics_typography.dart';
import '../utils/noticias_forum.dart';

/// Seguir el apartado Noticias (avisos al publicar).
class NoticiasFollowButton extends ConsumerWidget {
  const NoticiasFollowButton({
    super.key,
    this.heroStyle = false,
  });

  /// Compacto para el hero oscuro (junto a la lupa).
  final bool heroStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    if (!supabaseReady) return const SizedBox.shrink();

    final followingAsync = ref.watch(isFollowingForumProvider(noticiasForumId));

    return followingAsync.when(
      skipLoadingOnReload: true,
      loading: () => heroStyle
          ? _NoticiasHeroFollowChip(
              isFollowing: false,
              onTap: () => _toggle(context, ref, false),
            )
          : _NoticiasFollowChip(
              isFollowing: false,
              onTap: () => _toggle(context, ref, false),
            ),
      error: (_, _) => const SizedBox.shrink(),
      data: (isFollowing) => heroStyle
          ? _NoticiasHeroFollowChip(
              isFollowing: isFollowing,
              onTap: () => _toggle(context, ref, isFollowing),
            )
          : _NoticiasFollowChip(
              isFollowing: isFollowing,
              onTap: () => _toggle(context, ref, isFollowing),
            ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool isFollowing,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await context.push(
        '/login?redirect=${Uri.encodeComponent('/noticias')}',
      );
      return;
    }

    if (!await ensureEmailVerifiedForEngage(context, ref)) return;

    try {
      await ref.read(forumFollowControllerProvider).toggle(
            forumId: noticiasForumId,
            currentlyFollowing: isFollowing,
          );
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/noticias')}',
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el seguimiento. '
            '¿Ejecutaste noticias_forum_follow.sql?',
          ),
        ),
      );
    }
  }
}

class _NoticiasHeroFollowChip extends StatelessWidget {
  const _NoticiasHeroFollowChip({
    required this.isFollowing,
    required this.onTap,
  });

  final bool isFollowing;
  final VoidCallback onTap;

  /// Ancho fijo para que Seguir ↔ Siguiendo no mueva el header.
  static const _width = 108.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: 34,
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white,
              border: Border.all(
                color: isFollowing
                    ? AppColors.gold.withValues(alpha: 0.9)
                    : Colors.white,
                width: isFollowing ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFollowing
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_outlined,
                  size: 15,
                  color: isFollowing ? AppColors.goldDark : AppColors.burgundy,
                ),
                const SizedBox(width: 4),
                Text(
                  isFollowing ? 'Siguiendo' : 'Seguir',
                  style: ForumTopicsTypography.style(
                    color:
                        isFollowing ? AppColors.goldDark : AppColors.burgundy,
                    fontWeight: FontWeight.w800,
                  ).copyWith(fontSize: 11.5, height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticiasFollowChip extends StatelessWidget {
  const _NoticiasFollowChip({
    required this.isFollowing,
    required this.onTap,
  });

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: isFollowing
                  ? AppColors.goldPale.withValues(alpha: 0.55)
                  : AppColors.surface,
              border: Border.all(
                color: isFollowing
                    ? AppColors.gold.withValues(alpha: 0.55)
                    : AppColors.burgundy.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFollowing
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_outlined,
                  size: 15,
                  color: isFollowing ? AppColors.goldDark : AppColors.burgundy,
                ),
                const SizedBox(width: 6),
                Text(
                  isFollowing ? 'Siguiendo noticias' : 'Seguir noticias',
                  style: ForumTopicsTypography.style(
                    color:
                        isFollowing ? AppColors.goldDark : AppColors.burgundy,
                    fontWeight: FontWeight.w700,
                  ).copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
