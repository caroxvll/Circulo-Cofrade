import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import '../forums/widgets/forums_beige_background.dart';
import 'data/profile_from_user.dart';
import 'profile_design.dart';
import 'profile_provider.dart';
import 'widgets/own_profile_menu.dart';
import 'widgets/email_verification_banner.dart';
import 'widgets/following_tab.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_tab.dart';
import 'widgets/profile_pill_tab_bar.dart';
import 'widgets/profile_screen_header.dart';
import 'widgets/publications_tab.dart';
import 'widgets/suspended_account_banner.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAuth = user != null;

    if (!isAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go('/login?redirect=${Uri.encodeComponent('/perfil')}');
      });
      return const _ProfileTextureBackground(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final profileAsync = ref.watch(currentUserProfileProvider);

    return _ProfileTextureBackground(
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ProfileBody(
          profile: userProfileFromAuth(user),
          isAuthenticated: true,
        ),
        data: (profile) => _ProfileBody(profile: profile, isAuthenticated: true),
      ),
    );
  }
}

class _ProfileTextureBackground extends StatelessWidget {
  const _ProfileTextureBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: forumsBeigeDecorationImage(context),
      ),
      child: child,
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.isAuthenticated});

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
                padding: const EdgeInsets.fromLTRB(
                  ProfileDesign.screenPadding,
                  10,
                  ProfileDesign.screenPadding,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileScreenHeader(
                      menuButton: isAuthenticated
                          ? IconButton(
                              tooltip: 'Opciones de cuenta',
                              onPressed: () => showOwnProfileMenu(context, ref),
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: AppColors.burgundy,
                              ),
                            )
                          : null,
                    ),
                    if (isAuthenticated && profile.isSuspended) ...[
                      const SizedBox(height: 12),
                      SuspendedAccountBanner(reason: profile.suspendedReason),
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
                    const SizedBox(height: 14),
                    ProfileHeader(
                      profile: profile,
                      showFollowingCount: true,
                      onFollowingTap: () {
                        DefaultTabController.of(context).animateTo(1);
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileTabBarDelegate(
                tabBar: ProfilePillTabBar(
                  tabs: [
                    const ProfilePillTab(
                      icon: Icons.grid_view_rounded,
                      label: 'Actividad',
                    ),
                    if (isAuthenticated)
                      const ProfilePillTab(
                        icon: Icons.bookmark_outline_rounded,
                        label: 'Siguiendo',
                      ),
                    const ProfilePillTab(
                      icon: Icons.info_outline_rounded,
                      label: 'Información',
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              PublicationsTab(
                userId: profile.id,
                isAuthenticated: isAuthenticated,
              ),
              if (isAuthenticated) const FollowingTab(),
              ProfileInfoTab(
                profile: profile,
                isAuthenticated: isAuthenticated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
