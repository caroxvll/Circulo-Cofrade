import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../search_design.dart';

class SearchRecentChip extends StatelessWidget {
  const SearchRecentChip({
    super.key,
    required this.query,
    required this.onTap,
  });

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.85),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history,
                  size: 14,
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    query,
                    style: AppTypography.labelSmall(
                      color: AppColors.textPrimary,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SearchRecentChipsWrap extends StatelessWidget {
  const SearchRecentChipsWrap({
    super.key,
    required this.queries,
    required this.onTap,
  });

  final List<String> queries;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SearchDesign.cardGap,
      runSpacing: SearchDesign.cardGap,
      children: [
        for (final query in queries)
          SearchRecentChip(
            query: query,
            onTap: () => onTap(query),
          ),
      ],
    );
  }
}
