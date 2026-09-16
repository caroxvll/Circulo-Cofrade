import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/mock_profile.dart';
import '../profile_design.dart';

class ProfileInlineStats extends StatelessWidget {
  const ProfileInlineStats({
    super.key,
    required this.topicCount,
    required this.followerCount,
    this.followingCount,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final int topicCount;
  final int followerCount;
  final int? followingCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            value: formatFollowerCount(topicCount),
            label: 'Temas',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            value: formatFollowerCount(followerCount),
            label: 'Seguidores',
            onTap: onFollowersTap,
          ),
        ),
        if (followingCount != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              value: formatFollowerCount(followingCount!),
              label: 'Siguiendo',
              onTap: onFollowingTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onTap != null
              ? AppColors.burgundy.withValues(alpha: 0.22)
              : AppColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: ProfileDesign.statValue().copyWith(fontSize: 18),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: ProfileDesign.statLabel().copyWith(
              fontSize: 10,
              color: onTap != null ? AppColors.burgundy : AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}
