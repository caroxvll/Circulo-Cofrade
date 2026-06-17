import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/mock_profile.dart';

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({
    super.key,
    required this.publicationCount,
    required this.followerCount,
  });

  final int publicationCount;
  final int followerCount;

  static const _cardColor = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                value: '$publicationCount',
                label: 'Publicaciones',
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            Expanded(
              child: _StatColumn(
                value: formatFollowerCount(followerCount),
                label: 'Seguidores',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.displaySmall(color: AppColors.textOnDark)
              .copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall(
            color: AppColors.goldLight,
          ).copyWith(fontSize: 12),
        ),
      ],
    );
  }
}
