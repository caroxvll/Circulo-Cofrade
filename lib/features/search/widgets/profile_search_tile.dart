import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../models/search_results.dart';
import '../search_design.dart';

class ProfileSearchTile extends StatelessWidget {
  const ProfileSearchTile({
    super.key,
    required this.profile,
    required this.onTap,
  });

  final SearchProfileHit profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SearchDesign.cardRadius),
        child: Ink(
          decoration: SearchDesign.cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CofradeoAvatar(
                  imageUrl: profile.avatarUrl,
                  size: 48,
                  backgroundColor: AppColors.backgroundElevated,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: AppTypography.titleLarge(
                                color: AppColors.textPrimary,
                              ).copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedAccountIcon(size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.handle,
                        style: AppTypography.labelSmall(
                          color: AppColors.burgundy,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          profile.bio,
                          style: SearchDesign.sectionMeta().copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
