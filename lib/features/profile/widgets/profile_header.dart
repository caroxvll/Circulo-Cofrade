import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../shared/models/user_profile.dart';
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CofradeoAvatar(
          imageUrl: profile.avatarUrl,
          icon: profile.avatarIcon,
          size: 72,
          backgroundColor: AppColors.burgundyDark,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: AppTypography.titleLarge().copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                profile.handle,
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              ),
              if (profile.role.canEditCalendar && !profile.role.isStaff) ...[
                const SizedBox(height: 8),
                const CofradeoBadge(label: 'Editor del calendario'),
              ],
              const SizedBox(height: 10),
              Text(
                profile.bio,
                style: AppTypography.bodyMedium().copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
