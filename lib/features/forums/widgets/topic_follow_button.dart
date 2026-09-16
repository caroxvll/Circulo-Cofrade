import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../forum_topics_typography.dart';
import '../../auth/email_verification_gate.dart';
import '../../search/follows_provider.dart';
import 'hermandad_follow_sections_sheet.dart';

class TopicFollowButton extends ConsumerWidget {
  const TopicFollowButton({
    super.key,
    required this.forumId,
    required this.topicId,
    this.isHermandadBoard = false,
    this.compact = false,
    this.heroStyle = false,
  });

  final String forumId;
  final String topicId;
  final bool isHermandadBoard;
  final bool compact;
  /// CTA ancho filled (hero del tablón oficial).
  final bool heroStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    if (!supabaseReady) return const SizedBox.shrink();

    final followingAsync = ref.watch(isFollowingTopicProvider(topicId));

    return followingAsync.when(
      loading: () => heroStyle
          ? const SizedBox(
              height: 28,
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
            )
          : SizedBox(
              height: compact ? 28 : 36,
              width: compact ? 88 : 120,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      error: (_, _) => const SizedBox.shrink(),
      data: (isFollowing) {
        if (heroStyle) {
          return _HermandadHeroFollowButton(
            isFollowing: isFollowing,
            onTap: () => _onHermandadTap(context, ref, isFollowing),
            onSettings: isFollowing
                ? () => _onHermandadTap(context, ref, true)
                : null,
          );
        }

        if (isHermandadBoard && isFollowing) {
          final categoriesAsync =
              ref.watch(topicFollowNotifyCategoriesProvider(topicId));
          return categoriesAsync.when(
            loading: () => _HermandadFollowingRow(
              notifyLabel: null,
              onTapChip: () => _onHermandadTap(context, ref, true),
              onTapSettings: () => _onHermandadTap(context, ref, true),
            ),
            error: (_, _) => _HermandadFollowingRow(
              notifyLabel: null,
              onTapChip: () => _onHermandadTap(context, ref, true),
              onTapSettings: () => _onHermandadTap(context, ref, true),
            ),
            data: (categories) => _HermandadFollowingRow(
              notifyLabel: hermandadNotifyCategoriesLabel(categories),
              onTapChip: () => _onHermandadTap(context, ref, true),
              onTapSettings: () => _onHermandadTap(context, ref, true),
            ),
          );
        }

        return _TopicFollowChip(
          isFollowing: isFollowing,
          isHermandadBoard: isHermandadBoard,
          compact: compact,
          onTap: () => isHermandadBoard
              ? _onHermandadTap(context, ref, isFollowing)
              : _onTap(context, ref, isFollowing),
        );
      },
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool isFollowing,
  ) async {
    if (!await _ensureCanFollow(context, ref)) return;

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
      _showFollowError(context);
    }
  }

  Future<void> _onHermandadTap(
    BuildContext context,
    WidgetRef ref,
    bool isFollowing,
  ) async {
    if (!await _ensureCanFollow(context, ref)) return;

    List<String>? initialCategories;
    if (isFollowing) {
      initialCategories =
          await ref.read(topicFollowNotifyCategoriesProvider(topicId).future);
    }

    if (!context.mounted) return;

    final outcome = await showHermandadFollowSectionsSheet(
      context,
      initialCategories: initialCategories,
      following: isFollowing,
    );

    if (!context.mounted || outcome == null) return;

    if (outcome.unfollow) {
      try {
        await ref.read(topicFollowControllerProvider).toggle(
              topicId: topicId,
              currentlyFollowing: true,
            );
      } catch (_) {
        _showFollowError(context);
      }
      return;
    }

    try {
      if (isFollowing) {
        await ref.read(topicFollowControllerProvider).updateNotifyCategories(
              topicId: topicId,
              notifyOfficialCategories: outcome.categories,
            );
      } else {
        await ref.read(topicFollowControllerProvider).toggle(
              topicId: topicId,
              currentlyFollowing: false,
              notifyOfficialCategories: outcome.categories,
            );
      }
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/foros/$forumId/tema/$topicId')}',
        );
      }
    } catch (_) {
      _showFollowError(context);
    }
  }

  Future<bool> _ensureCanFollow(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await context.push(
        '/login?redirect=${Uri.encodeComponent('/foros/$forumId/tema/$topicId')}',
      );
      return false;
    }

    return ensureEmailVerifiedForEngage(context, ref);
  }

  void _showFollowError(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo actualizar el seguimiento. ¿Ejecutaste topic_follows.sql?',
        ),
      ),
    );
  }
}

class _HermandadHeroFollowButton extends StatelessWidget {
  const _HermandadHeroFollowButton({
    required this.isFollowing,
    required this.onTap,
    this.onSettings,
  });

  final bool isFollowing;
  final VoidCallback onTap;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: isFollowing
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.burgundy,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isFollowing
                        ? AppColors.gold.withValues(alpha: 0.55)
                        : AppColors.burgundyDark.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFollowing
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 13,
                      color: AppColors.textOnDark,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isFollowing ? 'Siguiendo' : 'Seguir hermandad',
                      style: ForumTopicsTypography.style(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isFollowing && onSettings != null) ...[
          const SizedBox(width: 6),
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSettings,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.tune_outlined,
                  color: AppColors.textOnDark,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HermandadFollowingRow extends StatelessWidget {
  const _HermandadFollowingRow({
    required this.notifyLabel,
    required this.onTapChip,
    required this.onTapSettings,
  });

  final String? notifyLabel;
  final VoidCallback onTapChip;
  final VoidCallback onTapSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TopicFollowChip(
              isFollowing: true,
              isHermandadBoard: true,
              onTap: onTapChip,
            ),
            IconButton(
              onPressed: onTapSettings,
              icon: const Icon(Icons.tune_outlined),
              color: AppColors.burgundy,
              visualDensity: VisualDensity.compact,
              tooltip: 'Avisos del tablón',
            ),
          ],
        ),
        if (notifyLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            'Avisos: $notifyLabel',
            style: ForumTopicsTypography.style(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _TopicFollowChip extends StatelessWidget {
  const _TopicFollowChip({
    required this.isFollowing,
    required this.isHermandadBoard,
    required this.onTap,
    this.compact = false,
  });

  final bool isFollowing;
  final bool isHermandadBoard;
  final VoidCallback onTap;
  final bool compact;

  String get _followLabel =>
      isHermandadBoard ? 'Seguir hermandad' : 'Seguir hilo';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: isFollowing
                ? AppColors.goldPale.withValues(alpha: 0.55)
                : Colors.transparent,
            border: Border.all(
              color: isFollowing
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : AppColors.burgundy.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowing
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_outlined,
                size: compact ? 12 : 13,
                color: isFollowing ? AppColors.goldDark : AppColors.burgundy,
              ),
              SizedBox(width: compact ? 4 : 5),
              Text(
                isFollowing ? 'Siguiendo' : _followLabel,
                style: ForumTopicsTypography.style(
                  color: isFollowing ? AppColors.goldDark : AppColors.burgundy,
                  fontWeight: FontWeight.w600,
                ).copyWith(fontSize: compact ? 11 : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
