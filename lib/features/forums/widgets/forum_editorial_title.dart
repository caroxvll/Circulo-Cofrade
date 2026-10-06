import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../forum_topics_typography.dart';
import '../topic_detail_typography.dart';
import '../utils/forum_app_bar_kicker.dart';

/// Título + kicker editorial (estilo Noticias) para AppBars y heroes de foro.
class ForumEditorialTitle extends StatelessWidget {
  const ForumEditorialTitle({
    super.key,
    required this.title,
    required this.forumId,
    this.kicker,
    this.onDark = false,
    this.center = true,
    this.titleFontSize,
    this.maxTitleLines = 1,
  });

  final String title;
  final String forumId;

  /// Si es null, usa [forumTopicAppBarKicker].
  final String? kicker;
  final bool onDark;
  final bool center;
  final double? titleFontSize;
  final int maxTitleLines;

  @override
  Widget build(BuildContext context) {
    final resolvedKicker = kicker ?? forumTopicAppBarKicker(forumId);
    final align = center ? TextAlign.center : TextAlign.start;
    final isHermandadChannel = forumId == 'hermandades';
    final titleStyle = onDark
        ? AppTypography.displaySmall(color: AppColors.gold).copyWith(
            fontSize: titleFontSize ?? 20,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: 0.4,
          )
        : isHermandadChannel
            ? AppTypography.hermandadName(color: AppColors.burgundyDark)
                .copyWith(
                fontSize: titleFontSize ?? 18,
                fontWeight: FontWeight.w700,
                height: 1.05,
              )
            : TopicDetailTypography.editorialAppBarTitle().copyWith(
                fontSize: titleFontSize,
              );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle,
          maxLines: maxTitleLines,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
        ),
        Text(
          resolvedKicker,
          style: onDark
              ? ForumTopicsTypography.onDark(
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w600,
                ).copyWith(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  height: 1.15,
                )
              : isHermandadChannel
                  ? TopicDetailTypography.editorialAppBarKicker().copyWith(
                      color: AppColors.goldDark,
                      letterSpacing: 1.2,
                    )
                  : TopicDetailTypography.editorialAppBarKicker(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
        ),
      ],
    );
  }
}
