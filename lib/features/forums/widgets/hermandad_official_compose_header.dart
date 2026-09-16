import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';
import '../topic_detail_typography.dart';
import 'forum_compose_sheet_header.dart';

class HermandadOfficialComposeHeader extends StatelessWidget {
  const HermandadOfficialComposeHeader({
    super.key,
    this.closeEnabled = true,
  });

  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    return ForumComposeSheetTitleBar(
      closeEnabled: closeEnabled,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.burgundy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: AppColors.burgundy,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Publicar información oficial',
                  style: TopicDetailTypography.title().copyWith(fontSize: 15),
                ),
                Text(
                  'Comunicado en el tablón de la hermandad.',
                  style: ForumTopicsTypography.style(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
