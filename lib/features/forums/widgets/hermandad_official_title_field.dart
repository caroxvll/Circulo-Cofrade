import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../topic_detail_typography.dart';
import 'hermandad_compose_section_label.dart';

class HermandadOfficialTitleField extends StatelessWidget {
  const HermandadOfficialTitleField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HermandadComposeSectionLabel(
          title: 'TÍTULO',
          subtitle: 'Así aparece en el tablón.',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 90,
          style: TopicDetailTypography.title().copyWith(fontSize: 16, height: 1.25),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Título del comunicado',
            hintStyle: TopicDetailTypography.title().copyWith(
              fontSize: 16,
              height: 1.25,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.burgundy),
            ),
          ),
        ),
      ],
    );
  }
}
