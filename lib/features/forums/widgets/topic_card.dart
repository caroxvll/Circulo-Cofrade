import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';

class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  final ForumTopic topic;
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CofradeoAvatar(
                imageUrl: topic.authorAvatarUrl,
                icon: topic.avatarIcon,
                size: 44,
                backgroundColor: AppColors.backgroundElevated,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic.authorHandle,
                            style: AppTypography.bodyMedium(),
                          ),
                        ),
                        Text(
                          topic.timeAgo,
                          style: AppTypography.labelSmall(
                            color: AppColors.accentRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      topic.title,
                      style: AppTypography.displaySmall(
                        color: AppColors.textPrimary,
                      ).copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topic.excerpt,
                      style: AppTypography.bodyMedium(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${topic.commentCount}',
                          style: AppTypography.labelSmall(),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.visibility_outlined,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${formatCount(topic.viewCount)} vistas',
                          style: AppTypography.labelSmall(),
                        ),
                        const Spacer(),
                        if (topic.isResolved)
                          const CofradeoBadge(label: 'Resuelto'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
