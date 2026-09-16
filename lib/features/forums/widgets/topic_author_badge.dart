import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../topic_detail_typography.dart';

/// Etiqueta compacta para marcar al autor del tema en el hilo.
class TopicAuthorBadge extends StatelessWidget {
  const TopicAuthorBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.burgundy.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        'Autor',
        style: TopicDetailTypography.meta(
          color: AppColors.burgundy,
          fontWeight: FontWeight.w700,
        ).copyWith(fontSize: 9.5, letterSpacing: 0.2),
      ),
    );
  }
}
