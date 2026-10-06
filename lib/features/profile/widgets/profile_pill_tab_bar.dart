import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Tabs del perfil: TEMAS · SIGUIENDO · INFORMACIÓN (underline).
class ProfilePillTabBar extends StatelessWidget {
  const ProfilePillTabBar({super.key, required this.tabs});

  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        dividerColor: AppColors.border.withValues(alpha: 0.7),
        dividerHeight: 1,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.burgundy, width: 2.5),
          insets: EdgeInsets.symmetric(horizontal: 2),
        ),
        labelColor: AppColors.burgundy,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: AppTypography.labelSmall().copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: AppTypography.labelSmall(
          color: AppColors.textMuted,
        ).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        overlayColor: WidgetStateProperty.all(
          AppColors.burgundy.withValues(alpha: 0.06),
        ),
        splashFactory: NoSplash.splashFactory,
        tabs: tabs,
      ),
    );
  }
}

class ProfilePillTab extends StatelessWidget {
  const ProfilePillTab({
    super.key,
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 34,
      text: label.toUpperCase(),
    );
  }
}

class ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  ProfileTabBarDelegate({required this.tabBar, this.backgroundColor});

  final ProfilePillTabBar tabBar;
  final Color? backgroundColor;

  static const _verticalPadding = 6.0;
  static const _tabBarHeight = 42.0;

  @override
  double get minExtent => _tabBarHeight + _verticalPadding * 2;

  @override
  double get maxExtent => _tabBarHeight + _verticalPadding * 2;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: (backgroundColor ?? AppColors.background).withValues(
        alpha: overlapsContent ? 0.98 : 1,
      ),
      elevation: overlapsContent ? 1 : 0,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant ProfileTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar ||
      oldDelegate.backgroundColor != backgroundColor;
}
