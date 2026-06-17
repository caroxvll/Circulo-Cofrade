import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../constants/topic_moderation_copy.dart';

class TopicModerationBanner extends StatelessWidget {
  const TopicModerationBanner({
    super.key,
    required this.status,
    this.showPublishedConfirmation = false,
  });

  final TopicStatus status;
  final bool showPublishedConfirmation;

  @override
  Widget build(BuildContext context) {
    if (status == TopicStatus.published) {
      if (!showPublishedConfirmation) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.goldDark,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TopicModerationCopy.publishedTitle,
                    style: AppTypography.titleLarge().copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TopicModerationCopy.publishedBody,
                    style: AppTypography.bodyMedium(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isPending = status == TopicStatus.pending;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPending
            ? AppColors.goldPale.withValues(alpha: 0.35)
            : AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? AppColors.gold : AppColors.border,
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPending ? Icons.gavel_outlined : Icons.info_outline,
            color: AppColors.burgundy,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending
                      ? TopicModerationCopy.pendingTitle
                      : TopicModerationCopy.rejectedTitle,
                  style: AppTypography.titleLarge().copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  isPending
                      ? TopicModerationCopy.pendingBody
                      : TopicModerationCopy.rejectedBody,
                  style: AppTypography.bodyMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
