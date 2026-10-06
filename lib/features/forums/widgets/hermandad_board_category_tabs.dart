import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../utils/official_post_categories.dart';

/// Chips del canal oficial (Noticias · Cultos · Actos · Patrimonio).
/// El badge muestra solo entradas *nuevas* desde la última visita a esa sección.
class HermandadBoardCategoryTabs extends StatelessWidget {
  const HermandadBoardCategoryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.newCounts = const {},
    this.boardSubtitle,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  /// Novedades por categoría (no el total histórico).
  final Map<String, int> newCounts;

  /// Conservado por compatibilidad con el delegate.
  final String? boardSubtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          for (var i = 0; i < officialPostCategories.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _CategoryChip(
                label: officialPostCategories[i].label,
                icon: officialPostCategories[i].icon,
                selected: selected == officialPostCategories[i].value,
                newCount: newCounts[officialPostCategories[i].value] ?? 0,
                onTap: () => onSelected(officialPostCategories[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.newCount,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int newCount;
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.burgundy
                  : AppColors.burgundy.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall(color: fg).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              if (newCount > 0) ...[
                const SizedBox(width: 3),
                Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.gold
                        : AppColors.burgundy,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    newCount > 99 ? '99+' : '$newCount',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall(
                      color: selected
                          ? AppColors.burgundyDark
                          : AppColors.textOnDark,
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                      height: 1.15,
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
      ? '1 publicación · $label'
      : '$visibleCount publicaciones · $label';
}
