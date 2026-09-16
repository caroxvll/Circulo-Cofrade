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
  const NoticiasFollowButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    if (!supabaseReady) return const SizedBox.shrink();

    final followingAsync = ref.watch(isFollowingForumProvider(noticiasForumId));

    return followingAsync.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (isFollowing) => _NoticiasFollowChip(
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
        '/login?redirect=${Uri.encodeComponent('/foros/$noticiasForumId')}',
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
          '/login?redirect=${Uri.encodeComponent('/foros/$noticiasForumId')}',
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
      height: 36,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isFollowing
                  ? AppColors.goldPale.withValues(alpha: 0.55)
                  : Colors.transparent,
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
                  size: 16,
                  color: isFollowing ? AppColors.goldDark : AppColors.burgundy,
                ),
                const SizedBox(width: 6),
                Text(
                  isFollowing ? 'Siguiendo noticias' : 'Seguir noticias',
                  style: ForumTopicsTypography.style(
                    color: isFollowing ? AppColors.goldDark : AppColors.burgundy,
                    fontWeight: FontWeight.w700,
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
