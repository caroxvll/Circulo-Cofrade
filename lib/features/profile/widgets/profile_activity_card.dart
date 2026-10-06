import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../forums/data/forum_icons.dart';
import '../../../shared/models/forum.dart';
import '../../../shared/models/profile_activity.dart';
import '../profile_design.dart';

class ProfileActivityCard extends StatelessWidget {
  const ProfileActivityCard({
    super.key,
    required this.activity,
    this.dense = false,
    this.fillHeight = false,
  });

  final ProfileActivity activity;
  final bool dense;
  final bool fillHeight;

  bool get _isPending =>
      activity.isTopic && activity.topicStatus == TopicStatus.pending;

  String? get _coverUrl {
    final url = activity.coverImageUrl?.trim();
    if (url == null || url.isEmpty || url.startsWith('assets/')) return null;
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final preview = plainTextForExcerpt(
      activity.preview,
      maxLength: dense ? 70 : 90,
    );
    final forumIcon = forumIconFromKey(
      activity.forumIconKey,
      fallback: activity.isTopic ? Icons.edit_note_rounded : Icons.forum_outlined,
    );
    final coverUrl = _coverUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          '/foros/${activity.forumId}/tema/${activity.topicId}',
        ),
        borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
        child: Ink(
          decoration: ProfileDesign.cardDecoration(
            highlighted: _isPending,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
            child: fillHeight
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return _FillBody(
                        activity: activity,
                        preview: preview,
                        forumIcon: forumIcon,
                        coverUrl: coverUrl,
                        isPending: _isPending,
                        maxHeight: constraints.maxHeight,
                      );
                    },
                  )
                : Padding(
                    padding: EdgeInsets.all(dense ? 10.0 : 12.0),
                    child: _IntrinsicBody(
                      activity: activity,
                      preview: preview,
                      forumIcon: forumIcon,
                      coverUrl: coverUrl,
                      isPending: _isPending,
                      dense: dense,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Card a alto completo: portada a altura total a la derecha + texto a la izquierda.
class _FillBody extends StatelessWidget {
  const _FillBody({
    required this.activity,
    required this.preview,
    required this.forumIcon,
    required this.coverUrl,
    required this.isPending,
    required this.maxHeight,
  });

  final ProfileActivity activity;
  final String preview;
  final IconData forumIcon;
  final String? coverUrl;
  final bool isPending;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final h = maxHeight;
    final pad = h < 110 ? 8.0 : 10.0;
    final gap = h < 110 ? 4.0 : 6.0;
    final titleLines = h < 120 ? 2 : 3;
    final showExcerpt = h >= 115;
    final titleSize = h < 120 ? 13.0 : 14.0;
    final previewSize = 11.5;

    final excerptText = preview.isNotEmpty
        ? preview
        : (activity.isTopic
            ? 'Tema publicado en ${activity.forumName}'
            : 'Respuesta en ${activity.forumName}');

    final meta = Row(
      children: [
        Flexible(
          child: _ForumChip(
            icon: forumIcon,
            label: activity.forumName,
            compact: true,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          activity.timeAgo,
          style: ProfileDesign.meta().copyWith(fontSize: 10),
        ),
        if (isPending) ...[
          const SizedBox(width: 4),
          const _StatusChip(label: 'En revisión'),
        ],
      ],
    );

    final title = Text(
      activity.title,
      style: AppTypography.titleLarge().copyWith(
        fontSize: titleSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      maxLines: titleLines,
      overflow: TextOverflow.ellipsis,
    );

    final excerpt = Text(
      excerptText,
      style: AppTypography.bodyMedium(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: previewSize, height: 1.25),
      maxLines: h < 140 ? 2 : 3,
      overflow: TextOverflow.ellipsis,
    );

    final stats = _ActivityStats(
      viewCount: activity.viewCount,
      commentCount: activity.commentCount,
      reactionCount: activity.reactionCount,
      compact: true,
      alwaysShowViewsAndComments: true,
    );

    // Con portada: imagen a toda la altura del card (borde a borde).
    if (coverUrl != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 58,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, 10, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  meta,
                  SizedBox(height: gap),
                  Flexible(
                    fit: FlexFit.loose,
                    child: title,
                  ),
                  if (showExcerpt) ...[
                    SizedBox(height: gap * 0.6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: excerpt,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  SizedBox(height: gap),
                  stats,
                ],
              ),
            ),
          ),
          Expanded(
            flex: 42,
            child: SizedBox.expand(
              child: CofradeoNetworkImage(
                url: coverUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheSize: 400,
              ),
            ),
          ),
        ],
      );
    }

    // Sin portada: layout compacto solo texto.
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          meta,
          SizedBox(height: gap),
          Flexible(fit: FlexFit.loose, child: title),
          if (showExcerpt) ...[
            SizedBox(height: gap * 0.5),
            Expanded(child: Align(alignment: Alignment.topLeft, child: excerpt)),
          ] else
            const Spacer(),
          SizedBox(height: gap),
          stats,
        ],
      ),
    );
  }
}

class _IntrinsicBody extends StatelessWidget {
  const _IntrinsicBody({
    required this.activity,
    required this.preview,
    required this.forumIcon,
    required this.coverUrl,
    required this.isPending,
    required this.dense,
  });

  final ProfileActivity activity;
  final String preview;
  final IconData forumIcon;
  final String? coverUrl;
  final bool isPending;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final titleSize = dense ? 14.0 : 15.5;
    final previewSize = dense ? 11.5 : 12.5;
    final gap = dense ? 6.0 : 10.0;
    final excerptText = preview.isNotEmpty
        ? preview
        : (activity.isTopic
            ? 'Tema publicado en ${activity.forumName}'
            : 'Respuesta en ${activity.forumName}');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _ForumChip(
                        icon: forumIcon,
                        label: activity.forumName,
                        compact: dense,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activity.timeAgo,
                      style: ProfileDesign.meta()
                          .copyWith(fontSize: dense ? 10 : 11),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 6),
                      const _StatusChip(label: 'En revisión'),
                    ],
                  ],
                ),
                SizedBox(height: gap),
                Text(
                  activity.title,
                  style: AppTypography.titleLarge().copyWith(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: dense ? 4 : 6),
                Text(
                  excerptText,
                  style: AppTypography.bodyMedium(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: previewSize, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: gap),
                _ActivityStats(
                  viewCount: activity.viewCount,
                  commentCount: activity.commentCount,
                  reactionCount: activity.reactionCount,
                  compact: dense,
                  alwaysShowViewsAndComments: true,
                ),
              ],
            ),
          ),
          if (coverUrl != null) ...[
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: dense ? 88 : 100,
                child: CofradeoNetworkImage(
                  url: coverUrl!,
                  fit: BoxFit.cover,
                  width: dense ? 88 : 100,
                  height: double.infinity,
                  cacheSize: 220,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForumChip extends StatelessWidget {
  const _ForumChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: AppColors.goldDark),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelSmall(
                color: AppColors.goldDark,
              ).copyWith(
                fontSize: compact ? 9.5 : 10.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(
          color: AppColors.textOnDark,
        ).copyWith(fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActivityStats extends StatelessWidget {
  const _ActivityStats({
    required this.viewCount,
    required this.commentCount,
    required this.reactionCount,
    this.compact = false,
    this.alwaysShowViewsAndComments = false,
  });

  final int viewCount;
  final int commentCount;
  final int reactionCount;
  final bool compact;
  final bool alwaysShowViewsAndComments;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final gap = SizedBox(width: compact ? 12 : 14);

    if (alwaysShowViewsAndComments || viewCount > 0) {
      items.add(
        _StatItem(
          icon: Icons.visibility_outlined,
          value: viewCount,
          compact: compact,
        ),
      );
    }
    if (alwaysShowViewsAndComments || commentCount > 0) {
      if (items.isNotEmpty) items.add(gap);
      items.add(
        _StatItem(
          icon: Icons.chat_bubble_outline_rounded,
          value: commentCount,
          compact: compact,
        ),
      );
    }
    if (reactionCount > 0) {
      if (items.isNotEmpty) items.add(gap);
      items.add(
        _StatItem(
          icon: Icons.favorite_border_rounded,
          value: reactionCount,
          compact: compact,
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    this.compact = false,
  });

  final IconData icon;
  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 14 : 15, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: ProfileDesign.meta().copyWith(
            fontSize: compact ? 12 : 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
