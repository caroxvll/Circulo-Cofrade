import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/screen_title_row.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import 'data/mock_profile.dart';
import 'data/profile_from_user.dart';
import 'profile_provider.dart';
import 'widgets/own_profile_menu.dart';
import 'widgets/email_verification_banner.dart';
import 'widgets/following_tab.dart';
import 'widgets/info_card.dart';
import 'widgets/publications_tab.dart';
import 'widgets/profile_header.dart';
import 'widgets/suspended_account_banner.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final authRequired = ref.watch(authRequiredProvider);
    final isAuth = user != null;

    if (authRequired && !isAuth) {
      return const Center(child: CircularProgressIndicator());
    }

    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) {
        if (user == null) return const SizedBox.shrink();
        return _ProfileBody(
          profile: userProfileFromAuth(user),
          isAuthenticated: true,
        );
      },
      data: (profile) => _ProfileBody(
        profile: profile,
        isAuthenticated: isAuth,
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.profile,
    required this.isAuthenticated,
  });

  final UserProfile profile;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabCount = isAuthenticated ? 3 : 2;

    return DefaultTabController(
      length: tabCount,
      child: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScreenTitleRow(
                      title: 'Perfil',
                      trailing: isAuthenticated
                          ? [
                              IconButton(
                                tooltip: 'Opciones de cuenta',
                                onPressed: () =>
                                    showOwnProfileMenu(context, ref),
                                icon: const Icon(
                                  Icons.more_horiz,
                                  color: AppColors.burgundy,
                                ),
                              ),
                            ]
                          : const [],
                    ),
                    if (isAuthenticated && profile.isSuspended) ...[
                      const SizedBox(height: 12),
                      SuspendedAccountBanner(
                        reason: profile.suspendedReason,
                      ),
                    ],
                    if (isAuthenticated)
                      Consumer(
                        builder: (context, ref, _) {
                          if (ref.watch(isEmailVerifiedProvider)) {
                            return const SizedBox.shrink();
                          }
                          return const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: EmailVerificationBanner(),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    ProfileHeader(profile: profile),
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
                  tabs: [
                    const Tab(text: 'Publicaciones'),
                    if (isAuthenticated) const Tab(text: 'Siguiendo'),
                    const Tab(text: 'Acerca de'),
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
                isAuthenticated: isAuthenticated,
              ),
              if (isAuthenticated) const FollowingTab(),
              _AboutTab(profile: profile, isAuthenticated: isAuthenticated),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.profile,
    required this.isAuthenticated,
  });

  final UserProfile profile;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    final items = isAuthenticated && profile.address.isEmpty
        ? <ProfileInfoItem>[]
        : isAuthenticated
            ? _itemsFromProfile(profile)
            : mockProfileInfoItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Información', style: AppTypography.displaySmall()),
        const SizedBox(height: 16),
        if (items.isEmpty && isAuthenticated)
          Text(
            'Pulsa Editar para completar tu perfil.',
            style: AppTypography.bodyMedium(),
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            InfoCard(item: items[i]),
          ],
      ],
    );
  }

  List<ProfileInfoItem> _itemsFromProfile(UserProfile profile) {
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
    return items;
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
