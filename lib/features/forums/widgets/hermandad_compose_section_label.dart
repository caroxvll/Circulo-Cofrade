import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';

class HermandadComposeSectionLabel extends StatelessWidget {
  const HermandadComposeSectionLabel({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(title, style: ForumTopicsTypography.sectionLabel()),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ForumTopicsTypography.style(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
