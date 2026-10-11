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
    final avatarSize = _isSubReply ? 34.0 : 44.0;
    final showOverflow = !deleted &&
        ((manageOptions?.hasMenu ?? false) ||
            onShareTap != null ||
            onReportTap != null);
    final showOfficialMeta =
        !deleted && (reply.isOfficial || reply.isFeatured);
    final rank = !deleted && reply.authorId != null
        ? cofradeRankTitleForPoints(reply.authorTrophyPoints)
        : null;
    final handle = reply.authorHandle.startsWith('@')
        ? reply.authorHandle
        : '@${reply.authorHandle}';
    // Si ya mostramos «Respondiendo a @x», no repetir @x al inicio del texto.
    final bodyText = deleted
        ? reply.displayContent
        : _bodyWithoutLeadingParentMention(reply.content, parentHandle);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        highlighted && !_isSubReply ? 6 : 0,
        0,
        0,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: highlighted && !_isSubReply
              ? Border(
                  left: BorderSide(
                    color: AppColors.burgundy.withValues(alpha: 0.4),
                    width: 2,
                  ),
                )
              : null,
          color: deleted
              ? AppColors.backgroundElevated.withValues(alpha: 0.35)
              : (reply.isOfficial && !deleted
                  ? AppColors.burgundy.withValues(alpha: 0.02)
                  : null),
          borderRadius: deleted ? BorderRadius.circular(8) : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            highlighted && !_isSubReply ? 8 : 0,
            _isSubReply ? 6 : 8,
            deleted ? 4 : 0,
            _isSubReply ? 4 : 6,
          ),
          child: Row(
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
              SizedBox(width: _isSubReply ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: deleted ? null : onAuthorTap,
                            behavior: HitTestBehavior.opaque,
                            child: _AuthorHeader(
                              handle: handle,
                              verified: reply.authorVerified && !deleted,
                              isTopicAuthor: isTopicAuthor && !deleted,
                              timeAgo: reply.timeAgo,
                              isEdited: reply.isEdited,
                              rank: rank,
                              replyingTo: !deleted ? parentHandle : null,
                            ),
                          ),
                        ),
                        if (showOverflow)
                          _ReplyOverflowMenu(
                            manageOptions: manageOptions,
                            onShareTap: onShareTap,
                            onReportTap: !_isSubReply ? onReportTap : null,
                            showShare: !_isSubReply && onShareTap != null,
                          ),
                      ],
                    ),
                    if (showOfficialMeta) ...[
                      const SizedBox(height: 2),
                      _OfficialMetaRow(
                        reply: reply,
                        reactionCounts: reactionCounts,
                      ),
                    ],
                    const SizedBox(height: 3),
                    if (deleted)
                      Text(
                        bodyText,
                        style: TopicDetailTypography.body(
                          color: AppColors.textMuted,
                        ).copyWith(
                          fontStyle: FontStyle.italic,
                          fontSize: 14.5,
                          height: 1.32,
                        ),
                      )
                    else
                      ForumPostContent(
                        text: bodyText,
                        style: TopicDetailTypography.body().copyWith(
                          fontSize: 14.5,
                          height: 1.32,
                        ),
                        subtleLinks: true,
                        premium: reply.isOfficial,
                      ),
                    if (reply.isEdited && reply.editedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Editado ${formatTimeAgo(reply.editedAt!)}',
                        style: AppTypography.labelSmall(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 10.5),
                      ),
                    ],
                    if (hasImage) ...[
                      const SizedBox(height: 6),
                      ForumPostImage(
                        imageUrl: reply.imageUrl!,
                        shareText: _imageShareText(reply),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        maxPreviewHeight: 220,
                        showExpandHint: false,
                        fit: BoxFit.cover,
                      ),
                    ],
                    if (!deleted) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (onReplyTap != null)
                            GestureDetector(
                              onTap: onReplyTap,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  'Responder',
                                  style: TopicDetailTypography.meta(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ).copyWith(fontSize: 12.5),
                                ),
                              ),
                            ),
                          const Spacer(),
                          ReplyReactionsBar(
                            replyId: reply.id,
                            reactionCounts: _nonHeartCounts(reactionCounts),
                            userReaction: _isHeartReaction(userReaction)
                                ? null
                                : userReaction,
                            onReactionChanged: onReactionChanged == null
                                ? null
                                : (reaction) async {
                                    await onReactionChanged!(reaction);
                                  },
                            enabled: onReactionChanged != null,
                            compact: true,
                            alignEnd: true,
                            socialStyle: true,
                            hideEmptyPicker: true,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!deleted && onReactionChanged != null) ...[
                const SizedBox(width: 6),
                _InstagramLikeButton(
                  liked: _isHeartReaction(userReaction),
                  count: _heartCount(reactionCounts),
                  onTap: () async {
                    final next = _isHeartReaction(userReaction) ? null : '❤️';
                    await onReactionChanged!(next);
                  },
                  onLongPress: () => _showQuickReactionPicker(
                    context,
                    current: userReaction,
                    onPick: onReactionChanged!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _isHeartReaction(String? value) {
  if (value == null || value.isEmpty) return false;
  final display = replyReactionDisplay(value);
  return display == '❤️' || value == 'heart';
}

/// Quita el @padre del inicio del cuerpo si ya hay etiqueta «Respondiendo a».
String _bodyWithoutLeadingParentMention(String content, String? parentHandle) {
  if (parentHandle == null || parentHandle.trim().isEmpty) return content;
  final bare = parentHandle.trim().replaceFirst(RegExp(r'^@'), '');
  if (bare.isEmpty) return content;

  final pattern = RegExp(
    '^\\s*@${RegExp.escape(bare)}\\b[,:]?\\s*',
    caseSensitive: false,
  );
  final stripped = content.replaceFirst(pattern, '');
  // Si el mensaje era solo la mención, no dejar la tarjeta vacía.
  if (stripped.trim().isEmpty) return content;
  return stripped;
}

int _heartCount(Map<String, int> counts) {
  final normalized = normalizeReactionCounts(counts);
  return normalized['❤️'] ?? 0;
}

Map<String, int> _nonHeartCounts(Map<String, int> counts) {
  final normalized = Map<String, int>.from(normalizeReactionCounts(counts));
  normalized.remove('❤️');
  return normalized;
}

Future<void> _showQuickReactionPicker(
  BuildContext context, {
  required String? current,
  required Future<void> Function(String? reaction) onPick,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Reaccionar',
                style: AppTypography.bodyMedium().copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final reaction in quickReplyReactions)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, reaction.emoji),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: reactionsEqual(current, reaction.emoji)
                              ? AppColors.burgundy.withValues(alpha: 0.1)
                              : AppColors.backgroundElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reaction.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (selected == null) return;
  final next = reactionsEqual(current, selected) ? null : selected;
  await onPick(next);
}

/// Cabecera IG: «Respondiendo a» + @handle; tiempo/rango en 2.ª línea (sin cortar).
class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({
    required this.handle,
    required this.verified,
    required this.isTopicAuthor,
    required this.timeAgo,
    required this.isEdited,
    this.rank,
    this.replyingTo,
  });

  final String handle;
  final bool verified;
  final bool isTopicAuthor;
  final String timeAgo;
  final bool isEdited;
  final String? rank;
  final String? replyingTo;

  @override
  Widget build(BuildContext context) {
    final metaStyle = TopicDetailTypography.meta(
      color: AppColors.textMuted,
    ).copyWith(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.2);
    final parent = replyingTo?.trim();
    final parentHandle = parent == null || parent.isEmpty
        ? null
        : (parent.startsWith('@') ? parent : '@$parent');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parentHandle != null) ...[
          Text.rich(
            TextSpan(
              style: metaStyle.copyWith(fontSize: 11.5),
              children: [
                const TextSpan(text: 'Respondiendo a '),
                TextSpan(
                  text: parentHandle,
                  style: const TextStyle(
                    color: AppColors.burgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
        ],
        Row(
          children: [
            Flexible(
              child: Text(
                handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium().copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  height: 1.15,
                  letterSpacing: -0.1,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (verified) ...[
              const SizedBox(width: 4),
              const VerifiedAccountIcon(size: 13),
            ],
            if (isTopicAuthor) ...[
              const SizedBox(width: 5),
              const TopicAuthorBadge(),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          [
            timeAgo,
            if (isEdited) 'editado',
            if (rank != null && rank!.trim().isNotEmpty) rank!.trim(),
          ].join(' · '),
          style: AppTypography.rankTitle(
            color: AppColors.textSecondary,
          ).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _OfficialMetaRow extends StatelessWidget {
  const _OfficialMetaRow({
    required this.reply,
    required this.reactionCounts,
  });

  final ForumReply reply;
  final Map<String, int> reactionCounts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        if (reply.isOfficial)
          Text(
            'Oficial · ${_categoryLabel(reply.officialCategory)}',
            style: TopicDetailTypography.meta(
              color: AppColors.burgundy,
              fontWeight: FontWeight.w700,
            ).copyWith(fontSize: 10.5),
          ),
        if (reply.isFeatured)
          Text(
            reply.isOfficial ? 'Fijada' : 'Destacada',
            style: TopicDetailTypography.meta(
              color: AppColors.burgundy,
              fontWeight: FontWeight.w600,
            ).copyWith(fontSize: 10.5),
          ),
        if (reply.isOfficial && totalReactionCount(reactionCounts) > 0)
          GestureDetector(
            onTap: () => showReplyReactionStatsSheet(
              context,
              replyId: reply.id,
              reactionCounts: reactionCounts,
            ),
            child: Text(
              '${totalReactionCount(reactionCounts)} reacc.',
              style: TopicDetailTypography.meta(
                color: AppColors.goldDark,
                fontWeight: FontWeight.w600,
              ).copyWith(fontSize: 10.5),
            ),
          ),
      ],
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

/// Corazón a la derecha, estilo Instagram.
class _InstagramLikeButton extends StatelessWidget {
  const _InstagramLikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
    this.onLongPress,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: liked ? AppColors.accentRed : AppColors.textMuted,
            ),
            if (count > 0) ...[
              const SizedBox(height: 1),
              Text(
                '$count',
                style: TopicDetailTypography.meta(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ).copyWith(fontSize: 11, height: 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplyOverflowMenu extends StatelessWidget {
  const _ReplyOverflowMenu({
    this.manageOptions,
    this.onShareTap,
    this.onReportTap,
    this.showShare = false,
  });

  final ReplyManageOptions? manageOptions;
  final VoidCallback? onShareTap;
  final VoidCallback? onReportTap;
  final bool showShare;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: AppColors.textMuted.withValues(alpha: 0.75),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: 'Más opciones',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            manageOptions?.onEdit?.call();
          case 'delete':
            manageOptions?.onDelete?.call();
          case 'feature':
            manageOptions?.onToggleFeature?.call();
          case 'ban':
            manageOptions?.onBanFromForum?.call();
          case 'share':
            onShareTap?.call();
          case 'report':
            onReportTap?.call();
        }
      },
      itemBuilder: (context) {
        final options = manageOptions;
        return [
          if (options?.canEdit ?? false)
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
          if (options?.canFeature ?? false)
            PopupMenuItem(
              value: 'feature',
              child: Text(
                options!.isFeatured
                    ? (options.pinOfficialStyle
                        ? 'Quitar fijado'
                        : 'Quitar destacado')
                    : (options.pinOfficialStyle
                        ? 'Fijar arriba del tablón'
                        : 'Destacar respuesta'),
              ),
            ),
          if (showShare && onShareTap != null)
            const PopupMenuItem(value: 'share', child: Text('Compartir')),
          if (options?.canBanFromForum ?? false)
            const PopupMenuItem(
              value: 'ban',
              child: Text('Expulsar del foro'),
            ),
          if (onReportTap != null)
            const PopupMenuItem(value: 'report', child: Text('Reportar')),
          if (options?.canDelete ?? false)
            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ];
      },
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
