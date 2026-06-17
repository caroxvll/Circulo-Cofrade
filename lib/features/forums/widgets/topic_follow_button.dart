import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../search/follows_provider.dart';

class TopicFollowButton extends ConsumerWidget {
  const TopicFollowButton({
    super.key,
    required this.forumId,
    required this.topicId,
  });

  final String forumId;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    if (!supabaseReady) return const SizedBox.shrink();

    final followingAsync = ref.watch(isFollowingTopicProvider(topicId));

    return followingAsync.when(
      loading: () => const SizedBox(
        height: 36,
        width: 120,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (isFollowing) => Align(
        alignment: Alignment.centerLeft,
        child: _TopicFollowChip(
          isFollowing: isFollowing,
          onTap: () => _onTap(context, ref, isFollowing),
        ),
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool isFollowing,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await context.push(
        '/login?redirect=${Uri.encodeComponent('/foros/$forumId/tema/$topicId')}',
      );
      return;
    }

    if (!await ensureEmailVerifiedForEngage(context, ref)) return;

    try {
      await ref.read(topicFollowControllerProvider).toggle(
            topicId: topicId,
            currentlyFollowing: isFollowing,
          );
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/foros/$forumId/tema/$topicId')}',
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar el seguimiento. ¿Ejecutaste topic_follows.sql?',
            ),
          ),
        );
      }
    }
  }
}

class _TopicFollowChip extends StatelessWidget {
  const _TopicFollowChip({
    required this.isFollowing,
    required this.onTap,
  });

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isFollowing ? Colors.transparent : AppColors.burgundy,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isFollowing
                ? Border.all(color: AppColors.burgundy)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowing ? Icons.notifications_active_outlined : Icons.notifications_outlined,
                size: 16,
                color: isFollowing ? AppColors.burgundy : AppColors.textOnDark,
              ),
              const SizedBox(width: 6),
              Text(
                isFollowing ? 'Siguiendo hilo' : 'Seguir hilo',
                style: AppTypography.labelSmall(
                  color: isFollowing ? AppColors.burgundy : AppColors.textOnDark,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
