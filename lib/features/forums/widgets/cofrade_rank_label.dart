import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../topic_detail_typography.dart';

/// Rango cofrade visible bajo el @handle (p. ej. «Diputado de Tramo»).
class CofradeRankLabel extends StatelessWidget {
  const CofradeRankLabel({
    super.key,
    required this.title,
    this.compact = false,
  });

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty) return const SizedBox.shrink();

    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TopicDetailTypography.meta(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ).copyWith(fontSize: compact ? 10 : 11),
    );
  }
}
