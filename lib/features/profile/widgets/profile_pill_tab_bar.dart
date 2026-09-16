import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ProfilePillTabBar extends StatelessWidget {
  const ProfilePillTabBar({super.key, required this.tabs});

  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.burgundy,
                AppColors.burgundyDark.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundy.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: AppColors.textOnDark,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.labelSmall().copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
          unselectedLabelStyle: AppTypography.labelSmall(
            color: AppColors.textSecondary,
          ).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          tabs: tabs,
        ),
      ),
    );
  }
}

class ProfilePillTab extends StatelessWidget {
  const ProfilePillTab({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, height: 1),
          ),
        ],
      ),
    );
  }
}

class ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  ProfileTabBarDelegate({required this.tabBar, this.backgroundColor});

  final ProfilePillTabBar tabBar;
  final Color? backgroundColor;

  static const _verticalPadding = 10.0;
  static const _tabBarHeight = 54.0;

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
