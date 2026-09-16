import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../forums/data/mock_forums.dart';
import '../data/mock_search.dart';
import '../search_design.dart';

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
      decoration: SearchDesign.cardDecoration(
        highlighted: isFollowing,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onHashtagTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        CofradeoAvatar(
                          icon: trend.avatarIcon,
                          size: 46,
                          backgroundColor: AppColors.burgundyDark,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trend.hashtag,
                                style: AppTypography.titleLarge(
                                  color: AppColors.burgundy,
                                ).copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${formatCount(trend.postCount)} publicaciones',
                                style: SearchDesign.sectionMeta(),
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
      color: isFollowing
          ? AppColors.goldPale.withValues(alpha: 0.35)
          : AppColors.burgundy,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: isFollowing
                ? Border.all(color: AppColors.gold.withValues(alpha: 0.45))
                : null,
          ),
          child: Text(
            isFollowing ? 'Siguiendo' : 'Seguir',
            style: AppTypography.labelSmall(
              color: isFollowing ? AppColors.goldDark : AppColors.textOnDark,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
