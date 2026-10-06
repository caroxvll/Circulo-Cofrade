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
    this.flat = false,
  });

  final int topicCount;
  final int followerCount;
  final int? followingCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _StatItem(
        value: formatFollowerCount(topicCount),
        label: 'Temas',
        flat: flat,
      ),
      _StatItem(
        value: formatFollowerCount(followerCount),
        label: 'Seguidores',
        onTap: onFollowersTap,
        flat: flat,
      ),
      if (followingCount != null)
        _StatItem(
          value: formatFollowerCount(followingCount!),
          label: 'Siguiendo',
          onTap: onFollowingTap,
          flat: flat,
        ),
    ];

    if (flat) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: AppColors.gold.withValues(alpha: 0.28),
              ),
            Expanded(child: items[i]),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: items[i]),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    this.onTap,
    this.flat = false,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final child = flat
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: ProfileDesign.statValue().copyWith(fontSize: 17),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: ProfileDesign.statLabel().copyWith(
                    fontSize: 10,
                    color: onTap != null
                        ? AppColors.burgundy
                        : AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        : Container(
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
                    color: onTap != null
                        ? AppColors.burgundy
                        : AppColors.textMuted,
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
        borderRadius: BorderRadius.circular(flat ? 8 : 12),
        child: child,
      ),
    );
  }
}
