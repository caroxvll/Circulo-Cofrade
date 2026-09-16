import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../forums/data/forum_icons.dart';
import '../../../shared/models/forum.dart';
import '../../../shared/models/profile_activity.dart';
import '../profile_design.dart';

class ProfileActivityCard extends StatelessWidget {
  const ProfileActivityCard({super.key, required this.activity});

  final ProfileActivity activity;

  bool get _isPending =>
      activity.isTopic && activity.topicStatus == TopicStatus.pending;

  @override
  Widget build(BuildContext context) {
    final preview = plainTextForExcerpt(activity.preview, maxLength: 90);
    final forumIcon = forumIconFromKey(
      activity.forumIconKey,
      fallback: activity.isTopic ? Icons.edit_note_rounded : Icons.forum_outlined,
    );
    final typeLabel = activity.isTopic ? 'Tema' : 'Respuesta';

    final accentColor = _isPending
        ? AppColors.gold
        : AppColors.burgundy.withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          '/foros/${activity.forumId}/tema/${activity.topicId}',
        ),
        borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
          child: Ink(
            decoration: ProfileDesign.cardDecoration(
              highlighted: _isPending,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    color: accentColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ForumChip(
                                icon: forumIcon,
                                label: activity.forumName,
                              ),
                              const Spacer(),
                              _TypeChip(label: typeLabel),
                              if (_isPending) ...[
                                const SizedBox(width: 6),
                                const _StatusChip(label: 'En revisión'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            activity.title,
                            style: AppTypography.titleLarge().copyWith(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preview.isNotEmpty
                                ? preview
                                : (activity.isTopic
                                    ? 'Tema publicado en ${activity.forumName}'
                                    : 'Respuesta en ${activity.forumName}'),
                            style: AppTypography.bodyMedium(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 12.5, height: 1.35),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                activity.timeAgo,
                                style:
                                    ProfileDesign.meta().copyWith(fontSize: 11),
                              ),
                              const Spacer(),
                              _ActivityStats(
                                viewCount: activity.viewCount,
                                commentCount: activity.commentCount,
                                reactionCount: activity.reactionCount,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForumChip extends StatelessWidget {
  const _ForumChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          Icon(icon, size: 13, color: AppColors.goldDark),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              style: AppTypography.labelSmall(
                color: AppColors.goldDark,
              ).copyWith(
                fontSize: 10.5,
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.75),
        ),
      ),
      child: Text(
        label,
        style: ProfileDesign.meta().copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(
          color: AppColors.textOnDark,
        ).copyWith(fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActivityStats extends StatelessWidget {
  const _ActivityStats({
    required this.viewCount,
    required this.commentCount,
    required this.reactionCount,
  });

  final int viewCount;
  final int commentCount;
  final int reactionCount;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (viewCount > 0) {
      items.add(_StatItem(icon: Icons.visibility_outlined, value: viewCount));
    }
    if (commentCount > 0) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 10));
      items.add(_StatItem(icon: Icons.chat_bubble_outline_rounded, value: commentCount));
    }
    if (reactionCount > 0) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 10));
      items.add(_StatItem(icon: Icons.favorite_border_rounded, value: reactionCount));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: ProfileDesign.meta().copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
