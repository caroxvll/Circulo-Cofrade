import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../models/search_results.dart';

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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CofradeoAvatar(
                imageUrl: profile.avatarUrl,
                size: 44,
                backgroundColor: AppColors.backgroundElevated,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: AppTypography.titleLarge().copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.handle,
                      style: AppTypography.labelSmall(color: AppColors.burgundy),
                    ),
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.bio,
                        style: AppTypography.bodyMedium(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
