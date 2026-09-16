import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';
import '../topic_detail_typography.dart';
import '../utils/official_post_categories.dart';

/// Pestañas del tablón: chips horizontales (Todas · Noticias · Cultos…).
class HermandadBoardCategoryTabs extends StatelessWidget {
  const HermandadBoardCategoryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts = const {},
    this.boardSubtitle,
  });

  /// `null` = Todas las secciones.
  final String? selected;
  final ValueChanged<String?> onSelected;
  final Map<String, int> counts;
  final String? boardSubtitle;

  int get _totalCount =>
      counts.values.fold<int>(0, (sum, value) => sum + value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.burgundy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 12,
                  color: AppColors.burgundy,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tablón oficial',
                      style: TopicDetailTypography.meta(
                        color: AppColors.burgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      boardSubtitle ??
                          'Todas las publicaciones · Todas las secciones',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ForumTopicsTypography.style(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CategoryChip(
                label: 'Todas',
                icon: Icons.grid_view_rounded,
                selected: selected == null,
                count: _totalCount,
                onTap: () => onSelected(null),
              ),
              for (final cat in officialPostCategories) ...[
                const SizedBox(width: 5),
                _CategoryChip(
                  label: cat.label,
                  icon: cat.icon,
                  selected: selected == cat.value,
                  count: counts[cat.value] ?? 0,
                  onTap: () => onSelected(cat.value),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textOnDark : AppColors.burgundy;
    return Material(
      color: selected ? AppColors.burgundy : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppColors.burgundy
                    : AppColors.burgundy.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: fg),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: ForumTopicsTypography.style(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : AppColors.burgundy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: ForumTopicsTypography.style(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ),
    );
  }
}

String hermandadBoardSectionSubtitle({
  required String? selectedCategory,
  required int visibleCount,
}) {
  if (selectedCategory == null) {
    if (visibleCount == 0) {
      return 'Sin publicaciones todavía';
    }
    return visibleCount == 1
        ? '1 publicación · todas las secciones'
        : '$visibleCount publicaciones · todas las secciones';
  }

  final label = officialCategoryLabel(selectedCategory);
  if (visibleCount == 0) {
    return 'Sin publicaciones en $label';
  }
  return visibleCount == 1
      ? '1 publicación en $label'
      : '$visibleCount publicaciones en $label';
}
