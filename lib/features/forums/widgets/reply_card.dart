import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/forum_post_content.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../../shared/models/forum.dart';
import 'forum_post_image.dart';
import '../topic_detail_typography.dart';
import '../utils/official_post_categories.dart';
import '../utils/reply_reactions.dart';
import '../utils/cofrade_gamification.dart';
import 'cofrade_rank_label.dart';
import 'topic_author_badge.dart';
import 'reply_reaction_stats_sheet.dart';
import 'reply_reactions_bar.dart';

class ReplyManageOptions {
  const ReplyManageOptions({
    this.canEdit = false,
    this.canDelete = false,
    this.canFeature = false,
    this.isFeatured = false,
    this.canBanFromForum = false,
    this.pinOfficialStyle = false,
    this.onEdit,
    this.onDelete,
    this.onToggleFeature,
    this.onBanFromForum,
  });

  final bool canEdit;
  final bool canDelete;
  final bool canFeature;
  final bool isFeatured;
  final bool canBanFromForum;
  final bool pinOfficialStyle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFeature;
  final VoidCallback? onBanFromForum;

  bool get hasMenu =>
      canEdit || canDelete || canFeature || canBanFromForum;
}

class ReplyCard extends StatelessWidget {
  const ReplyCard({
    super.key,
    required this.reply,
    this.depth = 0,
    this.parentHandle,
    this.onAuthorTap,
    this.onReplyTap,
    this.reactionCounts = const {},
    this.userReaction,
    this.onReactionChanged,
    this.onReportTap,
    this.onShareTap,
    this.manageOptions,
    this.highlighted = false,
    this.isTopicAuthor = false,
  });

  final ForumReply reply;
  final int depth;
  final String? parentHandle;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReplyTap;
  final Map<String, int> reactionCounts;
  final String? userReaction;
  final Future<void> Function(String? reaction)? onReactionChanged;
  final VoidCallback? onReportTap;
  final VoidCallback? onShareTap;
  final ReplyManageOptions? manageOptions;
  final bool highlighted;
  final bool isTopicAuthor;

  bool get _isSubReply => depth > 0;

  @override
  Widget build(BuildContext context) {
    if (!reply.isDeleted &&
        reply.content.trim().isEmpty &&
        (reply.imageUrl == null || reply.imageUrl!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    final deleted = reply.isDeleted;
    final hasImage =
        reply.imageUrl != null && reply.imageUrl!.trim().isNotEmpty && !deleted;
    const avatarSize = 36.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        highlighted && !_isSubReply ? 8 : 0,
        0,
        0,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: highlighted && !_isSubReply
              ? Border(
                  left: BorderSide(
                    color: AppColors.burgundy.withValues(alpha: 0.45),
                    width: 2,
                  ),
                )
              : null,
          color: deleted
              ? AppColors.backgroundElevated.withValues(alpha: 0.45)
              : (reply.isOfficial && !deleted
                  ? AppColors.burgundy.withValues(alpha: 0.03)
                  : null),
          borderRadius: deleted ? BorderRadius.circular(8) : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            highlighted && !_isSubReply ? 10 : 0,
            deleted ? 10 : (_isSubReply ? 10 : 12),
            deleted ? 8 : 0,
            deleted ? 10 : (_isSubReply ? 10 : 12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: deleted ? null : onAuthorTap,
                    child: CofradeoAvatar(
                      imageUrl: reply.authorAvatarUrl,
                      icon: reply.avatarIcon,
                      size: avatarSize,
                      backgroundColor: AppColors.backgroundElevated,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (parentHandle != null && !deleted) ...[
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Respondiendo a ',
                                  style: TopicDetailTypography.meta(
                                    color: AppColors.textMuted,
                                  ).copyWith(fontSize: 12),
                                ),
                                TextSpan(
                                  text: parentHandle,
                                  style: TopicDetailTypography.meta(
                                    color: AppColors.burgundy,
                                    fontWeight: FontWeight.w700,
                                  ).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: deleted ? null : onAuthorTap,
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            reply.authorHandle,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                TopicDetailTypography.body()
                                                    .copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              height: 1.15,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (reply.authorVerified &&
                                            !deleted) ...[
                                          const SizedBox(width: 4),
                                          const VerifiedAccountIcon(
                                            size: 14,
                                          ),
                                        ],
                                        if (isTopicAuthor && !deleted) ...[
                                          const SizedBox(width: 6),
                                          const TopicAuthorBadge(),
                                        ],
                                        Text(
                                          ' · ${reply.timeAgo}',
                                          style: TopicDetailTypography.meta(
                                            color: AppColors.textMuted,
                                          ).copyWith(fontSize: 11.5),
                                        ),
                                        if (reply.isEdited)
                                          Text(
                                            ' · editado',
                                            style: TopicDetailTypography.meta(
                                              color: AppColors.textMuted,
                                            ).copyWith(fontSize: 11.5),
                                          ),
                                      ],
                                    ),
                                    if (!deleted &&
                                        (reply.authorId != null ||
                                            reply.isOfficial ||
                                            reply.isFeatured)) ...[
                                      const SizedBox(height: 2),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 2,
                                        children: [
                                          if (reply.authorId != null)
                                            CofradeRankLabel(
                                              title: cofradeRankTitleForPoints(
                                                reply.authorTrophyPoints,
                                              ),
                                              compact: true,
                                            ),
                                          if (reply.isOfficial)
                                            _OfficialInlineChip(
                                              category: reply.officialCategory,
                                            ),
                                          if (reply.isFeatured)
                                            Text(
                                              reply.isOfficial
                                                  ? 'Fijada'
                                                  : 'Destacada',
                                              style:
                                                  TopicDetailTypography.meta(
                                                color: AppColors.burgundy,
                                                fontWeight: FontWeight.w700,
                                              ).copyWith(fontSize: 11),
                                            ),
                                          if (reply.isOfficial &&
                                              totalReactionCount(
                                                      reactionCounts) >
                                                  0)
                                            GestureDetector(
                                              onTap: () =>
                                                  showReplyReactionStatsSheet(
                                                context,
                                                replyId: reply.id,
                                                reactionCounts: reactionCounts,
                                              ),
                                              child: Text(
                                                '${totalReactionCount(reactionCounts)} reacc.',
                                                style:
                                                    TopicDetailTypography.meta(
                                                  color: AppColors.goldDark,
                                                  fontWeight: FontWeight.w600,
                                                ).copyWith(fontSize: 11),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (manageOptions?.hasMenu ?? false)
                              _ManageMenu(options: manageOptions!),
                            if (onShareTap != null &&
                                !deleted &&
                                !_isSubReply)
                              IconButton(
                                onPressed: onShareTap,
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 17,
                                ),
                                color: AppColors.textMuted,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                                tooltip: 'Compartir',
                              ),
                            if (onReportTap != null &&
                                !deleted &&
                                !_isSubReply)
                              IconButton(
                                onPressed: onReportTap,
                                icon: const Icon(
                                  Icons.flag_outlined,
                                  size: 17,
                                ),
                                color: AppColors.textMuted,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                                tooltip: 'Reportar',
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (deleted)
                          Text(
                            reply.displayContent,
                            style: AppTypography.bodyMedium(
                              color: AppColors.textMuted,
                            ).copyWith(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                          )
                        else
                          ForumPostContent(
                            text: reply.content,
                            style: TopicDetailTypography.body().copyWith(
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                            subtleLinks: true,
                            premium: reply.isOfficial,
                          ),
                        if (reply.isEdited && reply.editedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Editado ${formatTimeAgo(reply.editedAt!)}',
                            style: AppTypography.labelSmall(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        if (hasImage) ...[
                          const SizedBox(height: 10),
                          ForumPostImage(
                            imageUrl: reply.imageUrl!,
                            shareText: _imageShareText(reply),
                          ),
                        ],
                        if (!deleted) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (onReplyTap != null)
                                TextButton(
                                  onPressed: onReplyTap,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    'Responder',
                                    style: TopicDetailTypography.meta(
                                      color: AppColors.burgundy,
                                      fontWeight: FontWeight.w700,
                                    ).copyWith(fontSize: 12.5),
                                  ),
                                ),
                              const Spacer(),
                              ReplyReactionsBar(
                                replyId: reply.id,
                                reactionCounts: reactionCounts,
                                userReaction: userReaction,
                                onReactionChanged: onReactionChanged,
                                enabled: onReactionChanged != null,
                                compact: true,
                                alignEnd: true,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficialInlineChip extends StatelessWidget {
  const _OfficialInlineChip({this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Oficial · ${_categoryLabel(category)}',
        style: TopicDetailTypography.meta(
          color: AppColors.burgundy,
          fontWeight: FontWeight.w800,
        ).copyWith(fontSize: 10.5),
      ),
    );
  }

  String _categoryLabel(String? raw) {
    return switch (raw) {
      'culto' => 'Cultos',
      'acto' => 'Actos',
      'patrimonio' => 'Patrimonio',
      _ => 'Noticias',
    };
  }
}

class _ManageMenu extends StatelessWidget {
  const _ManageMenu({required this.options});

  final ReplyManageOptions options;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            options.onEdit?.call();
          case 'delete':
            options.onDelete?.call();
          case 'feature':
            options.onToggleFeature?.call();
          case 'ban':
            options.onBanFromForum?.call();
        }
      },
      itemBuilder: (context) => [
        if (options.canEdit)
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
        if (options.canFeature)
          PopupMenuItem(
            value: 'feature',
            child: Text(
              options.isFeatured
                  ? (options.pinOfficialStyle
                      ? 'Quitar fijado'
                      : 'Quitar destacado')
                  : (options.pinOfficialStyle
                      ? 'Fijar arriba del tablón'
                      : 'Destacar respuesta'),
            ),
          ),
        if (options.canBanFromForum)
          const PopupMenuItem(
            value: 'ban',
            child: Text('Expulsar del foro'),
          ),
        if (options.canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }
}

String? _imageShareText(ForumReply reply) {
  if (reply.imageUrl == null || reply.imageUrl!.trim().isEmpty) return null;
  final excerpt = plainTextForExcerpt(reply.content, maxLength: 90);
  if (reply.isOfficial) {
    final section = reply.officialCategory != null
        ? officialCategoryLabel(reply.officialCategory!)
        : 'Tablón oficial';
    if (excerpt.isEmpty) return 'Comunicado oficial · $section · Cofradeo';
    return '$excerpt · $section · Cofradeo';
  }
  if (excerpt.isEmpty) return 'Cofradeo';
  return '$excerpt · Cofradeo';
}
