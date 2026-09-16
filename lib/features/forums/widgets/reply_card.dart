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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        highlighted && !_isSubReply ? 8 : 0,
        _isSubReply ? 4 : 10,
        0,
        _isSubReply ? 4 : 10,
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
              : null,
          borderRadius: deleted ? BorderRadius.circular(8) : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            highlighted && !_isSubReply ? 10 : 0,
            deleted ? 8 : 0,
            deleted ? 8 : 0,
            deleted ? 8 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (parentHandle != null && !deleted) ...[
                Text(
                  '↳ En respuesta a $parentHandle',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (reply.isOfficial && !deleted) ...[
                _OfficialReplyBadge(category: reply.officialCategory),
                const SizedBox(height: 8),
              ],
              if (reply.imageUrl != null &&
                  reply.imageUrl!.trim().isNotEmpty &&
                  !deleted) ...[
                ForumPostImage(
                  imageUrl: reply.imageUrl!,
                  shareText: _imageShareText(reply),
                ),
                const SizedBox(height: 8),
              ],
              if (reply.isFeatured && !deleted) ...[
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.burgundy),
                    const SizedBox(width: 4),
                    Text(
                      reply.isOfficial
                          ? 'Fijada arriba del tablón'
                          : 'Destacada por el titular',
                      style: AppTypography.labelSmall(color: AppColors.burgundy),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CofradeoAvatar(
                    imageUrl: reply.authorAvatarUrl,
                    icon: reply.avatarIcon,
                    size: _isSubReply ? 26 : 32,
                    backgroundColor: AppColors.backgroundElevated,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
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
                                        style: TopicDetailTypography.meta(
                                          color: !deleted && onAuthorTap != null
                                              ? AppColors.burgundy
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (reply.authorVerified && !deleted) ...[
                                      const SizedBox(width: 4),
                                      VerifiedAccountIcon(
                                        size: _isSubReply ? 13 : 15,
                                      ),
                                    ],
                                    if (isTopicAuthor && !deleted) ...[
                                      const SizedBox(width: 6),
                                      const TopicAuthorBadge(),
                                    ],
                                  ],
                                ),
                                if (!deleted && reply.authorId != null) ...[
                                  const SizedBox(height: 1),
                                  CofradeRankLabel(
                                    title: cofradeRankTitleForPoints(
                                      reply.authorTrophyPoints,
                                    ),
                                    compact: _isSubReply,
                                  ),
                                ],
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 0,
                                  children: [
                                    Text(
                                      reply.timeAgo,
                                      style: TopicDetailTypography.meta(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    if (reply.isEdited) ...[
                                      Text(
                                        ' · editado',
                                        style: AppTypography.labelSmall(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                    if (reply.isOfficial &&
                                        !deleted &&
                                        totalReactionCount(reactionCounts) >
                                            0) ...[
                                      GestureDetector(
                                        onTap: () =>
                                            showReplyReactionStatsSheet(
                                          context,
                                          replyId: reply.id,
                                          reactionCounts: reactionCounts,
                                        ),
                                        child: Text(
                                          ' · ${totalReactionCount(reactionCounts)} reacc.',
                                          style: TopicDetailTypography.meta(
                                            color: AppColors.goldDark,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (manageOptions?.hasMenu ?? false)
                          _ManageMenu(options: manageOptions!),
                        if (onShareTap != null && !deleted)
                          IconButton(
                            onPressed: onShareTap,
                            icon: const Icon(Icons.share_outlined, size: 18),
                            color: AppColors.textMuted,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: 'Compartir',
                          ),
                        if (onReportTap != null && !deleted)
                          IconButton(
                            onPressed: onReportTap,
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            color: AppColors.textMuted,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: 'Reportar',
                          ),
                      ],
                    ),
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
                    fontSize: _isSubReply ? 13 : 14,
                  ),
                )
              else
                ForumPostContent(
                  text: reply.content,
                  style: TopicDetailTypography.body().copyWith(
                    fontSize: _isSubReply
                        ? 12.5
                        : TopicDetailTypography.bodySize + 1,
                    height: 1.55,
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Responder',
                          style: TopicDetailTypography.meta(
                            color: AppColors.burgundy,
                            fontWeight: FontWeight.w600,
                          ),
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
      ),
    );
  }
}

class _OfficialReplyBadge extends StatelessWidget {
  const _OfficialReplyBadge({this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign_outlined, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            'Oficial · ${_categoryLabel(category)}',
            style: AppTypography.labelSmall(
              color: AppColors.textOnDark,
            ).copyWith(fontSize: 11),
          ),
        ],
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
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  ? (options.pinOfficialStyle ? 'Quitar fijado' : 'Quitar destacado')
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
