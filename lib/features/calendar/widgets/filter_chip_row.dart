import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';

/// Chips en varias filas: todas las categorías visibles sin scroll horizontal.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final EventFilter selected;
  final ValueChanged<EventFilter> onSelected;

  static const _filters = EventFilter.values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _filters.map((filter) {
        final isSelected = filter == selected;

        return FilterChip(
          label: Text(filter.label),
          selected: isSelected,
          onSelected: (_) => onSelected(filter),
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          labelStyle: AppTypography.bodyMedium(
            color:
                isSelected ? AppColors.chipSelectedText : AppColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w500, fontSize: 12),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.chipSelected,
          side: BorderSide(
            color: isSelected ? AppColors.gold : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
        );
      }).toList(),
    );
  }
}
