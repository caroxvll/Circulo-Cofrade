import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
    this.appBarStyle = false,
    this.overlayStyle = false,
  });

  final String forumId;
  final String topicId;
  final bool isHermandadBoard;
  final bool compact;
  /// CTA ancho filled (hero del tablón oficial).
  final bool heroStyle;
  /// Iconos compactos para la AppBar (seguir + campana).
  final bool appBarStyle;
  /// Iconos claros sobre el hero/imagen (esquina superior).
  final bool overlayStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    if (!supabaseReady) return const SizedBox.shrink();

    final followingAsync = ref.watch(isFollowingTopicProvider(topicId));

    return followingAsync.when(
      skipLoadingOnReload: true,
      loading: () {
        if (overlayStyle) {
          return _HermandadOverlayFollowActions(
            isFollowing: false,
            onFollowTap: () => _onHermandadTap(context, ref, false),
          );
        }
        if (appBarStyle) {
          return _HermandadAppBarFollowActions(
            isFollowing: false,
            onFollowTap: () => _onHermandadTap(context, ref, false),
          );
        }
        if (heroStyle) {
          return _HermandadHeroFollowButton(
            isFollowing: false,
            onTap: () => _onHermandadTap(context, ref, false),
          );
        }
        return _TopicFollowChip(
          isFollowing: false,
          isHermandadBoard: isHermandadBoard,
          compact: compact,
          onTap: () => isHermandadBoard
              ? _onHermandadTap(context, ref, false)
              : _onTap(context, ref, false),
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      data: (isFollowing) {
        if (overlayStyle) {
          return _HermandadOverlayFollowActions(
            isFollowing: isFollowing,
            onFollowTap: () => _onHermandadTap(context, ref, isFollowing),
            onBellTap: isFollowing
                ? () => _onHermandadTap(context, ref, true)
                : null,
          );
        }
        if (appBarStyle) {
          return _HermandadAppBarFollowActions(
            isFollowing: isFollowing,
            onFollowTap: () => _onHermandadTap(context, ref, isFollowing),
            onBellTap: isFollowing
                ? () => _onHermandadTap(context, ref, true)
                : null,
          );
        }
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
            skipLoadingOnReload: true,
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

class _HermandadOverlayFollowActions extends StatelessWidget {
  const _HermandadOverlayFollowActions({
    required this.isFollowing,
    required this.onFollowTap,
    this.onBellTap,
  });

  final bool isFollowing;
  final VoidCallback onFollowTap;
  final VoidCallback? onBellTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverlayIconButton(
          onTap: onFollowTap,
          tooltip: isFollowing ? 'Siguiendo' : 'Seguir hermandad',
          icon: isFollowing
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
        ),
        if (isFollowing && onBellTap != null) ...[
          const SizedBox(width: 6),
          _OverlayIconButton(
            onTap: onBellTap!,
            tooltip: 'Avisos del tablón',
            icon: Icons.notifications_outlined,
          ),
        ],
      ],
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.onTap,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.42),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.1,
              ),
            ),
            child: Icon(icon, color: AppColors.textOnDark, size: 17),
          ),
        ),
      ),
    );
  }
}

class _HermandadAppBarFollowActions extends StatelessWidget {
  const _HermandadAppBarFollowActions({
    required this.isFollowing,
    required this.onFollowTap,
    this.onBellTap,
  });

  final bool isFollowing;
  final VoidCallback onFollowTap;
  final VoidCallback? onBellTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onFollowTap,
          tooltip: isFollowing ? 'Siguiendo' : 'Seguir hermandad',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isFollowing
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: AppColors.burgundy,
          ),
        ),
        if (isFollowing && onBellTap != null)
          IconButton(
            onPressed: onBellTap,
            tooltip: 'Avisos del tablón',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.burgundy,
            ),
          ),
      ],
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

  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                height: _height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isFollowing
                      ? Colors.black.withValues(alpha: 0.42)
                      : AppColors.burgundy.withValues(alpha: 0.92),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFollowing
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 14,
                      color: AppColors.textOnDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFollowing ? 'Siguiendo' : 'Seguir',
                      style: AppTypography.buttonLabel(
                        color: AppColors.textOnDark,
                      ).copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isFollowing && onSettings != null) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onSettings,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: _height,
                  height: _height,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.42),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textOnDark,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
