import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/mock_profile.dart';
import '../profile_design.dart';

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({
    super.key,
    required this.publicationCount,
    required this.followerCount,
  });

  final int publicationCount;
  final int followerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: ProfileDesign.cardDecoration(highlighted: true),
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
              color: AppColors.border.withValues(alpha: 0.8),
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
        Text(value, style: ProfileDesign.statValue()),
        const SizedBox(height: 4),
        Text(label, style: ProfileDesign.statLabel()),
      ],
    );
  }
}
