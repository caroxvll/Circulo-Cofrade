import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../calendar_design_tokens.dart';

enum FilterChipLayout { horizontal, wrap }

/// Chips de filtro del calendario.
/// [FilterChipLayout.horizontal]: scroll con degradado (pantalla principal).
/// [FilterChipLayout.wrap]: todos visibles (bottom sheet).
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
    this.layout = FilterChipLayout.horizontal,
  });

  final EventFilter selected;
  final ValueChanged<EventFilter> onSelected;
  final FilterChipLayout layout;

  static const filters = [
    EventFilter.todas,
    EventFilter.procesiones,
    EventFilter.igualas,
    EventFilter.ensayos,
    EventFilter.conciertos,
    EventFilter.glorias,
    EventFilter.eventos,
    EventFilter.guardados,
  ];

  @override
  Widget build(BuildContext context) {
    if (layout == FilterChipLayout.wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in filters)
            _FilterChip(
              filter: filter,
              isSelected: filter == selected,
              onSelected: () => onSelected(filter),
            ),
        ],
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: CalendarDesign.chipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final filter = filters[index];
              return _FilterChip(
                filter: filter,
                isSelected: filter == selected,
                onSelected: () => onSelected(filter),
              );
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background.withValues(alpha: 0.85),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.isSelected,
    required this.onSelected,
  });

  final EventFilter filter;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(filter.label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelStyle: AppTypography.bodyMedium(
        color: isSelected ? AppColors.textOnDark : AppColors.textSecondary,
      ).copyWith(
        fontWeight: FontWeight.w600,
        fontSize: CalendarDesign.chipFontSize,
      ),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.burgundy,
      side: BorderSide(
        color: isSelected
            ? AppColors.burgundy
            : AppColors.border.withValues(alpha: 0.8),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CalendarDesign.chipRadius),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CalendarDesign.chipHorizontalPadding,
      ),
      labelPadding: EdgeInsets.zero,
    );
  }
}
