import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/mention_rich_text.dart';
import '../../../shared/models/forum.dart';

class ReplyManageOptions {
  const ReplyManageOptions({
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });

  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  bool get hasMenu => canEdit || canDelete;
}

class ReplyCard extends StatelessWidget {
  const ReplyCard({
    super.key,
    required this.reply,
    this.depth = 0,
    this.parentHandle,
    this.onAuthorTap,
    this.onReplyTap,
    this.isLiked = false,
    this.onLikeTap,
    this.onReportTap,
    this.manageOptions,
    this.highlighted = false,
  });

  final ForumReply reply;
  final int depth;
  final String? parentHandle;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReplyTap;
  final bool isLiked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onReportTap;
  final ReplyManageOptions? manageOptions;
  final bool highlighted;

  bool get _isSubReply => depth > 0;

  @override
  Widget build(BuildContext context) {
    if (!reply.isDeleted && reply.content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final deleted = reply.isDeleted;

    return Padding(
      padding: EdgeInsets.only(left: _isSubReply ? 16.0 : 0),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          padding: EdgeInsets.all(_isSubReply ? 12 : 16),
          decoration: BoxDecoration(
            color: deleted
                ? AppColors.backgroundElevated.withValues(alpha: 0.6)
                : (_isSubReply
                    ? AppColors.backgroundElevated
                    : AppColors.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted
                  ? AppColors.burgundy
                  : (_isSubReply ? AppColors.burgundy : AppColors.border),
              width: highlighted ? 2 : (_isSubReply ? 1.5 : 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (parentHandle != null && !deleted) ...[
                Text(
                  '↳ En respuesta a $parentHandle',
                  style: AppTypography.labelSmall(color: AppColors.burgundy),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CofradeoAvatar(
                    imageUrl: reply.authorAvatarUrl,
                    icon: reply.avatarIcon,
                    size: _isSubReply ? 32 : 40,
                    backgroundColor: AppColors.backgroundElevated,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: deleted ? null : onAuthorTap,
                                child: Text(
                                  reply.authorHandle,
                                  style: TextStyle(
                                    fontSize: _isSubReply ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: !deleted && onAuthorTap != null
                                        ? AppColors.burgundy
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              reply.timeAgo,
                              style: AppTypography.labelSmall(
                                color: AppColors.accentRed,
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
                            if (manageOptions?.hasMenu ?? false)
                              _ManageMenu(options: manageOptions!),
                            if (onReportTap != null && !deleted) ...[
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
                              fontSize: _isSubReply ? 14 : 16,
                            ),
                          )
                        else
                          MentionRichText(
                            text: reply.content,
                            style: TextStyle(
                              fontSize: _isSubReply ? 14 : 16,
                              height: 1.45,
                              color: AppColors.textPrimary,
                            ),
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
                      ],
                    ),
                  ),
                ],
              ),
              if (!deleted) ...[
                const SizedBox(height: 10),
                Row(
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
                          style: AppTypography.labelSmall(
                            color: AppColors.burgundy,
                          ),
                        ),
                      ),
                    const Spacer(),
                    InkWell(
                      onTap: onLikeTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: isLiked
                                  ? AppColors.accentRed
                                  : AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${reply.likeCount}',
                              style: AppTypography.labelSmall(
                                color: isLiked
                                    ? AppColors.accentRed
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
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
        }
      },
      itemBuilder: (context) => [
        if (options.canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: Text('Editar'),
          ),
        if (options.canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Eliminar'),
          ),
      ],
    );
  }
}
