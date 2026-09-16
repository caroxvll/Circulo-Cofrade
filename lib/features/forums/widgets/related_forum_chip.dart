import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/mock_forums.dart';
import '../utils/noticias_forum.dart';

/// Chip «Relacionado con» en noticias (etiqueta a un foro, sin duplicar el tema).
class RelatedForumChip extends StatelessWidget {
  const RelatedForumChip({
    super.key,
    required this.relatedForumId,
    this.compact = false,
    this.onTap,
  });

  final String relatedForumId;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!isValidNoticiasRelatedForum(relatedForumId)) {
      return const SizedBox.shrink();
    }

    final forum = forumById(relatedForumId);
    final label = forum?.name ?? relatedForumId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            () => context.push('/foros/$relatedForumId'),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 3 : 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.burgundy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.burgundy.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: compact ? 12 : 13,
                color: AppColors.burgundyDark,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelSmall(
                    color: AppColors.burgundyDark,
                  ).copyWith(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
