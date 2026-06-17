import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import 'forum_last_activity_link.dart';

class ForumCategoryCard extends StatelessWidget {
  const ForumCategoryCard({
    super.key,
    required this.forum,
    required this.onTap,
  });

  final ForumCategory forum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = forum.isLocked;

    return Opacity(
      opacity: locked ? 0.72 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: locked
                        ? AppColors.textMuted.withValues(alpha: 0.25)
                        : AppColors.burgundy,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    locked ? Icons.lock_outline : forum.icon,
                    color: locked ? AppColors.textMuted : AppColors.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              forum.name,
                              style: AppTypography.displaySmall(
                                color: locked
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ).copyWith(fontSize: 17),
                            ),
                          ),
                          if (locked)
                            const CofradeoBadge(label: 'Próximamente')
                          else if (forum.isActive)
                            const CofradeoBadge(
                              label: 'Activo',
                              icon: Icons.local_fire_department,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        forum.description,
                        style: AppTypography.bodyMedium(
                          color: locked
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (locked && forum.lockedLabel != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 14,
                              color: AppColors.burgundy.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                forum.lockedLabel!,
                                style: AppTypography.labelSmall(
                                  color: AppColors.burgundy,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        Text(
                          formatForumStatsLine(forum),
                          style: AppTypography.labelSmall(),
                        ),
                        const SizedBox(height: 4),
                        ForumLastActivityLink(forum: forum),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  locked ? Icons.lock : Icons.chevron_right,
                  color: locked ? AppColors.textMuted : AppColors.goldDark,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
