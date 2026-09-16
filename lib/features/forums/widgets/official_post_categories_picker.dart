import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';
import '../utils/official_post_categories.dart';
import 'hermandad_compose_section_label.dart';

class OfficialPostCategoriesPicker extends StatelessWidget {
  const OfficialPostCategoriesPicker({
    super.key,
    required this.category,
    required this.onCategoryChanged,
  });

  final String category;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermandadComposeSectionLabel(
          title: 'SECCIÓN',
          subtitle: 'Dónde aparecerá en el tablón.',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < officialPostCategories.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _CategoryChip(
                  option: officialPostCategories[i],
                  selected: category == officialPostCategories[i].value,
                  onTap: () =>
                      onCategoryChanged(officialPostCategories[i].value),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final OfficialPostCategory option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textOnDark : AppColors.burgundy;

    return Material(
      color: selected ? AppColors.burgundy : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.burgundy
                  : AppColors.gold.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 16, color: fg),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  option.label,
                  maxLines: 1,
                  style: ForumTopicsTypography.style(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
