import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../forums/data/mock_forums.dart';
import '../data/mock_search.dart';

class TrendCard extends StatelessWidget {
  const TrendCard({
    super.key,
    required this.trend,
    required this.isFollowing,
    required this.onFollowToggle,
    this.onHashtagTap,
  });

  final SearchTrend trend;
  final bool isFollowing;
  final VoidCallback onFollowToggle;
  final VoidCallback? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onHashtagTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      CofradeoAvatar(
                        icon: trend.avatarIcon,
                        size: 44,
                        backgroundColor: AppColors.burgundyDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trend.hashtag,
                              style: AppTypography.titleLarge().copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatCount(trend.postCount)} posts',
                              style: AppTypography.labelSmall(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FollowButton(
            isFollowing: isFollowing,
            onTap: onFollowToggle,
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
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
          child: Text(
            isFollowing ? 'Siguiendo' : 'Seguir',
            style: AppTypography.labelSmall(
              color: isFollowing ? AppColors.burgundy : AppColors.textOnDark,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
