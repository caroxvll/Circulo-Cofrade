import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../search/follows_provider.dart';

class HistoriaFollowButton extends ConsumerWidget {
  const HistoriaFollowButton({
    super.key,
    required this.authorId,
    this.compact = false,
  });

  final String authorId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null || me.id == authorId) return const SizedBox.shrink();

    final following =
        ref.watch(followedProfilesProvider).asData?.value ?? const <String>{};
    final isFollowing = following.contains(authorId);

    return OutlinedButton(
      onPressed: () => _toggle(context, ref, isFollowing: isFollowing),
      style: OutlinedButton.styleFrom(
        foregroundColor: isFollowing ? AppColors.goldDark : AppColors.burgundy,
        side: BorderSide(
          color: isFollowing ? AppColors.gold : AppColors.burgundy,
        ),
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: compact ? 6 : 10,
        ),
      ),
      child: Text(
        isFollowing ? 'Siguiendo' : 'Seguir',
        style: AppTypography.labelSmall(
          color: isFollowing ? AppColors.goldDark : AppColors.burgundy,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: compact ? 11 : 12),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool isFollowing,
  }) async {
    if (!await ensureEmailVerifiedForEngage(context, ref)) return;
    try {
      await ref.read(profileFollowControllerProvider).toggle(
            profileId: authorId,
            currentlyFollowing: isFollowing,
          );
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push('/login');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el seguimiento.')),
        );
      }
    }
  }
}
