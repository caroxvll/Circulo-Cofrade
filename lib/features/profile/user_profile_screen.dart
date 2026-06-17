import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import '../auth/email_verification_gate.dart';
import '../search/data/follows_repository.dart';
import '../search/follows_provider.dart';
import 'profile_provider.dart';
import 'widgets/info_card.dart';
import 'widgets/profile_actions_menu.dart';
import 'widgets/profile_header.dart';
import 'widgets/publications_tab.dart';
import 'widgets/staff_profile_actions.dart';
import 'widgets/suspended_account_banner.dart';

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: Text(
          'Perfil',
          style: AppTypography.displaySmall().copyWith(fontSize: 17),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('No se pudo cargar el perfil')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil no encontrado'));
          }
          return _UserProfileBody(profile: profile);
        },
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
    final isFollowing = followed.contains(profile.id);

    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileHeader(profile: profile),
                  if (profile.isSuspended) ...[
                    const SizedBox(height: 12),
                    const SuspendedAccountBanner(compact: true),
                  ],
                  if (currentUser != null && supabaseReady) ...[
                    const SizedBox(height: 16),
                    _FollowProfileButton(
                      isFollowing: isFollowing,
                      onTap: () => _toggleFollow(context, ref, isFollowing),
                    ),
                  ],
                  if (supabaseReady) ...[
                    const SizedBox(height: 16),
                    StaffProfileActionsBar(profile: profile),
                  ],
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProfileTabBarDelegate(
              TabBar(
                labelStyle: AppTypography.titleLarge().copyWith(fontSize: 15),
                unselectedLabelStyle:
                    AppTypography.bodyLarge(color: AppColors.textMuted)
                        .copyWith(fontWeight: FontWeight.w500),
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.accentRed,
                indicatorWeight: 3,
                dividerColor: AppColors.border,
                tabs: const [
                  Tab(text: 'Publicaciones'),
                  Tab(text: 'Acerca de'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            PublicationsTab(
              userId: profile.id,
              publicationCount: profile.publicationCount,
              followerCount: profile.followerCount,
              isAuthenticated: true,
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Text('Información', style: AppTypography.displaySmall()),
                const SizedBox(height: 16),
                ..._infoItems(profile).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InfoCard(item: item),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    bool isFollowing,
  ) async {
    if (!await ensureEmailVerifiedForEngage(context, ref)) return;

    try {
      await ref.read(profileFollowControllerProvider).toggle(
            profileId: profile.id,
            currentlyFollowing: isFollowing,
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

  List<ProfileInfoItem> _infoItems(UserProfile profile) {
    final items = <ProfileInfoItem>[];
    if (profile.address.isNotEmpty) {
      items.add(ProfileInfoItem(
        icon: Icons.location_on_outlined,
        label: 'Dirección',
        value: profile.address,
      ));
    }
    if (profile.foundedLabel.isNotEmpty) {
      items.add(ProfileInfoItem(
        icon: Icons.calendar_today_outlined,
        label: 'Fundación',
        value: profile.foundedLabel,
      ));
    }
    if (profile.website.isNotEmpty) {
      items.add(ProfileInfoItem(
        icon: Icons.language_outlined,
        label: 'Sitio Web',
        value: profile.website,
      ));
    }
    if (items.isEmpty) {
      items.add(const ProfileInfoItem(
        icon: Icons.info_outline,
        label: 'Perfil',
        value: 'Sin información adicional.',
      ));
    }
    return items;
  }
}

class _FollowProfileButton extends StatelessWidget {
  const _FollowProfileButton({
    required this.isFollowing,
    required this.onTap,
  });

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: isFollowing ? Colors.transparent : AppColors.burgundy,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isFollowing
                  ? Border.all(color: AppColors.burgundy)
                  : null,
            ),
            child: Text(
              isFollowing ? 'Siguiendo' : 'Seguir',
              style: AppTypography.labelSmall(
                color: isFollowing ? AppColors.burgundy : AppColors.textOnDark,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  _ProfileTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) => false;
}
