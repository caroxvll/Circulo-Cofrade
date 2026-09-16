import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';

/// Último hilo activo del foro; enlaza al tema si hay datos.
class ForumLastActivityLink extends StatelessWidget {
  const ForumLastActivityLink({
    super.key,
    required this.forum,
    this.onDarkBackground = false,
    this.compact = false,
    this.accentColor,
    this.fontSize,
  });

  final ForumCategory forum;
  final bool onDarkBackground;
  final bool compact;
  final Color? accentColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final text = formatForumLastTopicLine(forum);
    if (text.isEmpty) return const SizedBox.shrink();

    final tone = accentColor ??
        (onDarkBackground ? Colors.white70 : AppColors.accentRed);

    final resolvedSize = fontSize ?? (compact ? 9.2 : 10.4);

    final style = AppTypography.labelSmall(
      color: onDarkBackground ? Colors.white70 : tone,
    ).copyWith(
      fontSize: resolvedSize,
      height: 1.12,
      fontWeight: FontWeight.w500,
    );

    final topicId = forum.lastTopicId;
    if (topicId != null && topicId.isNotEmpty && !forum.isLocked) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => context.push('/foros/${forum.id}/tema/$topicId'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: onDarkBackground ? Colors.white70 : tone,
          ),
          child: Text(
            text,
            style: style,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Text(
      text,
      style: style,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
