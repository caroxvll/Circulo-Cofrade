import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/cofradeo_skeleton.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import '../auth/email_verification_gate.dart';
import '../forums/widgets/forums_beige_background.dart';
import '../search/data/follows_repository.dart';
import '../search/follows_provider.dart';
import 'profile_design.dart';
import 'profile_provider.dart';
import 'widgets/profile_actions_menu.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_tab.dart';
import 'widgets/profile_pill_tab_bar.dart';
import 'widgets/publications_tab.dart';
import 'widgets/staff_profile_actions.dart';
import 'widgets/suspended_account_banner.dart';

/// Perfil de otro usuario: temas, trayectoria, stats… para cotillear.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider(userId));

    if (currentUser?.id == userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/perfil');
      });
      return const Scaffold(body: ProfileHomeSkeleton());
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: forumsBeigeDecorationImage(context),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
          ),
          title: Text(
            'PERFIL',
            style: AppTypography.screenAppBarTitle(),
          ),
          centerTitle: true,
          actions: [
            if (currentUser != null)
              IconButton(
                onPressed: () {
                  final profile = profileAsync.asData?.value;
                  if (profile == null) return;
                  showProfileActionsMenu(
                    context,
                    ref,
                    profileId: userId,
                    displayName: profile.displayName,
                  );
                },
                icon: const Icon(Icons.more_horiz, color: AppColors.burgundy),
              ),
          ],
        ),
        body: profileAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ProfileHomeSkeleton(),
          error: (_, _) =>
              const Center(child: Text('No se pudo cargar el perfil')),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Perfil no encontrado'));
            }
            return _UserProfileBody(profile: profile);
          },
        ),
      ),
    );
  }
}

class _UserProfileBody extends ConsumerWidget {
  const _UserProfileBody({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final followed = ref.watch(followedProfilesProvider).asData?.value ?? {};
    final pending =
        ref.watch(pendingOutgoingFollowRequestsProvider).asData?.value ?? {};
    final isFollowing = followed.contains(profile.id);
    final isRequested = !isFollowing && pending.contains(profile.id);
    final followingCountAsync =
        ref.watch(userFollowingCountProvider(profile.id));

    final canViewContent = !profile.isPrivate || isFollowing;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(
              profile: profile,
              showFollowingCount: canViewContent,
              followingCountOverride: canViewContent
                  ? followingCountAsync.asData?.value
                  : null,
              onFollowersTap: canViewContent
                  ? () => context.push(
                        '/perfil/usuario/${profile.id}/seguidores',
                      )
                  : null,
              onFollowingTap: canViewContent
                  ? () => context.push(
                        '/perfil/usuario/${profile.id}/siguiendo',
                      )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ProfileDesign.screenPadding,
                4,
                ProfileDesign.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (profile.isSuspended) ...[
                    const SuspendedAccountBanner(compact: true),
                    const SizedBox(height: 8),
                  ],
                  if (currentUser != null && supabaseReady) ...[
                    _FollowProfileButton(
                      isFollowing: isFollowing,
                      isRequested: isRequested,
                      onTap: () => _toggleFollow(
                        context,
                        ref,
                        isFollowing: isFollowing,
                        isRequested: isRequested,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (supabaseReady)
                    StaffProfileActionsBar(profile: profile),
                ],
              ),
            ),
            if (!canViewContent)
              const Expanded(child: _PrivateProfileLock())
            else ...[
              const ProfilePillTabBar(
                tabs: [
                  ProfilePillTab(label: 'Temas'),
                  ProfilePillTab(label: 'Información'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    PublicationsTab(
                      userId: profile.id,
                      isAuthenticated: true,
                    ),
                    ProfileInfoTab(
                      profile: profile,
                      isAuthenticated: currentUser != null,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref, {
    required bool isFollowing,
    required bool isRequested,
  }) async {
    if (!await ensureEmailVerifiedForEngage(context, ref)) return;

    try {
      await ref.read(profileFollowControllerProvider).toggle(
            profileId: profile.id,
            currentlyFollowing: isFollowing,
            currentlyRequested: isRequested,
            isPrivate: profile.isPrivate,
          );
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/perfil/usuario/${profile.id}')}',
        );
      }
    } on FollowsUnavailableException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el seguimiento.')),
        );
      }
    }
  }
}

class _PrivateProfileLock extends StatelessWidget {
  const _PrivateProfileLock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileDesign.screenPadding,
        24,
        ProfileDesign.screenPadding,
        24,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.burgundy.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 28,
              color: AppColors.burgundy,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Esta cuenta es privada',
            style: AppTypography.titleLarge().copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Síguela para ver sus temas, trayectoria e información. '
            'Si la cuenta es privada, tendrá que aceptar tu solicitud.',
            style: AppTypography.bodyMedium(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13.5, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FollowProfileButton extends StatelessWidget {
  const _FollowProfileButton({
    required this.isFollowing,
    required this.isRequested,
    required this.onTap,
  });

  final bool isFollowing;
  final bool isRequested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = isFollowing || isRequested;
    final label = isFollowing
        ? 'Siguiendo'
        : isRequested
            ? 'Solicitado'
            : 'Seguir';

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: muted ? Colors.transparent : AppColors.burgundy,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: muted
                    ? AppColors.border.withValues(alpha: 0.85)
                    : AppColors.burgundy,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.labelSmall(
                color: muted ? AppColors.textMuted : AppColors.textOnDark,
              ).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
