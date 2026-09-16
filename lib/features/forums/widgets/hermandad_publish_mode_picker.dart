import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';
import 'hermandad_compose_section_label.dart';

enum HermandadPublishMode { now, scheduled, draft }

class HermandadPublishModePicker extends StatelessWidget {
  const HermandadPublishModePicker({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final HermandadPublishMode mode;
  final ValueChanged<HermandadPublishMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HermandadComposeSectionLabel(
          title: 'PUBLICACIÓN',
          subtitle: 'Ahora, programada o borrador.',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ModeChip(
                icon: Icons.send_rounded,
                label: 'Ahora',
                selected: mode == HermandadPublishMode.now,
                onTap: () => onChanged(HermandadPublishMode.now),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ModeChip(
                icon: Icons.schedule_rounded,
                label: 'Programar',
                selected: mode == HermandadPublishMode.scheduled,
                onTap: () => onChanged(HermandadPublishMode.scheduled),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ModeChip(
                icon: Icons.edit_note_rounded,
                label: 'Borrador',
                selected: mode == HermandadPublishMode.draft,
                onTap: () => onChanged(HermandadPublishMode.draft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.burgundy
                  : AppColors.gold.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: ForumTopicsTypography.style(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
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
