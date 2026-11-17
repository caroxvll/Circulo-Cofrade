import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../utils/noticias_forum.dart';

/// Chip de etiqueta temática en noticias.
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
    final id = relatedForumId.trim();
    if (id.isEmpty) return const SizedBox.shrink();

    final label = noticiasCategoryLabel(id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
      ),
    );
  }
}
