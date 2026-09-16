import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../../shared/models/forum.dart';
import '../utils/official_post_categories.dart';

/// Franja compacta del comunicado fijado (anclada bajo las pestañas del tablón).
class HermandadPinnedPostStrip extends StatelessWidget {
  const HermandadPinnedPostStrip({
    super.key,
    required this.reply,
    this.onTap,
    this.elevated = false,
  });

  final ForumReply reply;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final excerpt = plainTextForExcerpt(reply.content, maxLength: 80);
    final category = reply.officialCategory;

    return Material(
      color: AppColors.background,
      elevation: elevated ? 2 : 0,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.08),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated,
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(Icons.push_pin, size: 16, color: AppColors.burgundy),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Fijada arriba del tablón',
                        style: AppTypography.labelSmall(
                          color: AppColors.burgundy,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        excerpt.isNotEmpty
                            ? excerpt
                            : category != null
                                ? officialCategoryLabel(category)
                                : 'Comunicado oficial',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HermandadPinnedPostDelegate extends SliverPersistentHeaderDelegate {
  HermandadPinnedPostDelegate({
    required this.reply,
    this.onTap,
  });

  final ForumReply reply;
  final VoidCallback? onTap;

  static const extent = 58.0;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: extent,
      child: HermandadPinnedPostStrip(
        reply: reply,
        onTap: onTap,
        elevated: overlapsContent || shrinkOffset > 0,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HermandadPinnedPostDelegate oldDelegate) {
    return oldDelegate.reply.id != reply.id ||
        oldDelegate.reply.content != reply.content ||
        oldDelegate.reply.isFeatured != reply.isFeatured ||
        oldDelegate.reply.officialCategory != reply.officialCategory;
  }
}
