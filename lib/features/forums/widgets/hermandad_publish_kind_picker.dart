import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';
import '../utils/hermandad_publish_kinds.dart';
import 'hermandad_compose_section_label.dart';

class HermandadPublishKindPicker extends StatelessWidget {
  const HermandadPublishKindPicker({
    super.key,
    required this.kindId,
    required this.onChanged,
  });

  final String kindId;
  final ValueChanged<HermandadPublishKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = hermandadPublishKindById(kindId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HermandadComposeSectionLabel(
          title: 'TIPO',
          subtitle: 'Qué estás anunciando.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final kind in hermandadPublishKinds)
              _KindChip(
                label: kind.label,
                selected: kind.id == selected.id,
                onTap: () => onChanged(kind),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'En tu tablón se verá en ${selected.boardSectionLabel}.',
          style: ForumTopicsTypography.style(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textOnDark : AppColors.burgundy;

    return Material(
      color: selected ? AppColors.burgundy : AppColors.surface,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? AppColors.burgundy
                  : AppColors.gold.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: ForumTopicsTypography.style(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
