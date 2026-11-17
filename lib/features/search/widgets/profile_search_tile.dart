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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: SearchDesign.cardDecoration().copyWith(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
            child: Row(
              children: [
                CofradeoAvatar(
                  imageUrl: profile.avatarUrl,
                  size: 36,
                  backgroundColor: AppColors.backgroundElevated,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: AppTypography.bodyMedium(
                                color: AppColors.textPrimary,
                              ).copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedAccountIcon(size: 12),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.handle,
                        style: AppTypography.labelSmall(
                          color: AppColors.burgundy,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          profile.bio,
                          style: SearchDesign.sectionMeta().copyWith(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
