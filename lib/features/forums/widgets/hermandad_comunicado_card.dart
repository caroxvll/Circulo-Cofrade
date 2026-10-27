import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../utils/hermandad_board_display.dart';
import 'forum_post_image_viewer.dart';
import 'reply_card.dart';
import 'topic_card.dart';

/// Card del canal oficial: jerarquía clara, extracto limpio e imagen ampliable.
class HermandadComunicadoCard extends StatefulWidget {
  const HermandadComunicadoCard({
    super.key,
    required this.reply,
    this.manageOptions,
    this.onShareTap,
    this.reactionCounts = const {},
    this.userReaction,
    this.onReactionChanged,
    /// Vista de detalle (sheet): contenido completo sin colapsar.
    this.detailView = false,
    /// Si se define, el tap abre el detalle en vez de expandir en el feed.
    this.onOpen,
    this.boardTopic,
  });

  final ForumReply reply;
  final ReplyManageOptions? manageOptions;
  final VoidCallback? onShareTap;
  final Map<String, int> reactionCounts;
  final String? userReaction;
  final Future<void> Function(String? reaction)? onReactionChanged;
  final bool detailView;
  final VoidCallback? onOpen;
  final ForumTopic? boardTopic;

  @override
  State<HermandadComunicadoCard> createState() => _HermandadComunicadoCardState();
}

class _HermandadComunicadoCardState extends State<HermandadComunicadoCard> {
  bool _expanded = false;

  bool get _showFull => widget.detailView || _expanded;

  void _onBodyTap() {
    if (widget.detailView) return;
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.reply;
    if (reply.isDeleted) {
      return ReplyCard(
        reply: reply,
        manageOptions: widget.manageOptions,
      );
    }

    final parsed = _parseOfficialContent(reply.content);
    final meta = _categoryMeta(reply.officialCategory);
    final imageUrl = reply.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final showBody = parsed.body.isNotEmpty &&
        parsed.body.trim().toLowerCase() != parsed.title.trim().toLowerCase();

    if (!widget.detailView) {
      return _FeedCard(
        onTap: _onBodyTap,
        hasImage: hasImage,
        imageUrl: imageUrl,
        shareText: parsed.title,
        meta: meta,
        timeAgo: reply.timeAgo,
        title: parsed.title,
        body: showBody ? parsed.body : null,
        manageOptions: widget.manageOptions,
        boardTopic: widget.boardTopic,
      );
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.045),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
              child: _HermandadByline(
                topic: widget.boardTopic,
                timeAgo: reply.timeAgo,
                manageOptions: widget.manageOptions,
                trailing: _CategoryPill(meta: meta, onDark: false),
              ),
            ),
            InkWell(
              onTap: widget.detailView ? null : _onBodyTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parsed.title,
                            maxLines: _showFull ? 8 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.hermandadName().copyWith(
                              fontSize: widget.detailView ? 20 : 17,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          if (showBody) ...[
                            const SizedBox(height: 6),
                            Text(
                              parsed.body,
                              maxLines: _showFull ? null : 3,
                              overflow: _showFull
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 13.5, height: 1.4),
                            ),
                          ],
                          if (widget.detailView && reply.viewCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              reply.viewCount == 1
                                  ? '1 visita'
                                  : '${reply.viewCount} visitas',
                              style: AppTypography.labelSmall(
                                color: AppColors.textMuted,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (!widget.detailView) ...[
                            const SizedBox(height: 8),
                            Text(
                              hasImage
                                  ? 'Leer más y ver cartel →'
                                  : 'Leer más →',
                              style: AppTypography.labelSmall(
                                color: AppColors.burgundy,
                              ).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasImage && !_showFull) ...[
                      const SizedBox(width: 12),
                      _ImageTile(
                        imageUrl: imageUrl,
                        shareText: parsed.title,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasImage && _showFull)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: _ImageTile(
                  imageUrl: imageUrl,
                  shareText: parsed.title,
                  compact: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HermandadByline extends StatelessWidget {
  const _HermandadByline({
    required this.topic,
    required this.timeAgo,
    this.manageOptions,
    this.trailing,
    this.compact = false,
  });

  final ForumTopic? topic;
  final String timeAgo;
  final ReplyManageOptions? manageOptions;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final board = topic;
    final rawName = board == null
        ? ''
        : parseHermandadTopicTitle(board.title).hermandadName.trim();
    final crest = compact ? 26.0 : 36.0;

    return Row(
      children: [
        if (board != null) ...[
          PinnedTopicMark(topic: board, size: crest, circular: true),
          SizedBox(width: compact ? 6 : 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rawName.isNotEmpty)
                Text(
                  rawName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: compact ? 11.5 : 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              Text(
                timeAgo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall(
                  color: AppColors.textMuted,
                ).copyWith(
                  fontSize: compact ? 10 : 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
        if (manageOptions != null) _ManageMini(options: manageOptions!),
      ],
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.onTap,
    required this.hasImage,
    required this.imageUrl,
    required this.shareText,
    required this.meta,
    required this.timeAgo,
    required this.title,
    required this.body,
    required this.manageOptions,
    required this.boardTopic,
  });

  final VoidCallback onTap;
  final bool hasImage;
  final String? imageUrl;
  final String shareText;
  final ({String kicker, IconData icon}) meta;
  final String timeAgo;
  final String title;
  final String? body;
  final ReplyManageOptions? manageOptions;
  final ForumTopic? boardTopic;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.burgundyDark.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasImage && imageUrl != null)
                  _Cover(
                    imageUrl: imageUrl!,
                    shareText: shareText,
                    meta: meta,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HermandadByline(
                        topic: boardTopic,
                        timeAgo: timeAgo,
                        manageOptions: manageOptions,
                        trailing: hasImage
                            ? null
                            : _CategoryPill(meta: meta, onDark: false),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.hermandadName().copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                      if (body != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(
                            color: AppColors.textSecondary,
                          ).copyWith(fontSize: 13.5, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.imageUrl,
    required this.shareText,
    required this.meta,
  });

  final String imageUrl;
  final String shareText;
  final ({String kicker, IconData icon}) meta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CofradeoNetworkImage(
            url: imageUrl,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.zero,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x66000000)],
                stops: [0.55, 1],
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: _CategoryPill(meta: meta, onDark: true),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: _ZoomBadgeButton(
              onTap: () => showForumPostImageViewer(
                context,
                imageUrl: imageUrl,
                shareText: shareText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.meta, required this.onDark});

  final ({String kicker, IconData icon}) meta;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : AppColors.burgundy;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onDark
            ? AppColors.burgundy.withValues(alpha: 0.92)
            : AppColors.burgundy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(meta.icon, size: 12, color: foreground),
            const SizedBox(width: 4),
            Text(
              meta.kicker,
              style: AppTypography.labelSmall(color: foreground).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.55,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomBadgeButton extends StatelessWidget {
  const _ZoomBadgeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.zoom_out_map_rounded,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.imageUrl,
    required this.compact,
    this.shareText,
  });

  final String imageUrl;
  final bool compact;
  final String? shareText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundElevated.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showForumPostImageViewer(
          context,
          imageUrl: imageUrl,
          shareText: shareText,
        ),
        child: compact
            ? SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CofradeoNetworkImage(
                      url: imageUrl,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const _ZoomBadge(compact: true),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 160,
                      maxHeight: 280,
                    ),
                    child: CofradeoNetworkImage(
                      url: imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      cacheSize: MediaQuery.sizeOf(context).width,
                    ),
                  ),
                  Container(
                    color: AppColors.burgundy.withValues(alpha: 0.06),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.zoom_out_map_rounded,
                          size: 16,
                          color: AppColors.burgundy.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Toca para ver el cartel a pantalla completa',
                            style: AppTypography.labelSmall(
                              color: AppColors.burgundy,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.burgundy.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: compact ? 5 : 8,
      bottom: compact ? 5 : 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 8,
            vertical: compact ? 4 : 5,
          ),
          child: Icon(
            Icons.zoom_out_map_rounded,
            size: compact ? 12 : 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Card compacta para el carrusel del tablón (desde la 2ª entrada).
class HermandadComunicadoRailCard extends StatelessWidget {
  const HermandadComunicadoRailCard({
    super.key,
    required this.reply,
    required this.onTap,
    this.boardTopic,
  });

  final ForumReply reply;
  final VoidCallback onTap;
  final ForumTopic? boardTopic;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseOfficialContent(reply.content);
    final meta = _categoryMeta(reply.officialCategory);
    final imageUrl = reply.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final showBody = parsed.body.isNotEmpty &&
        parsed.body.trim().toLowerCase() != parsed.title.trim().toLowerCase();

    return SizedBox(
      width: 200,
      height: 262,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.burgundyDark.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 112,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage)
                          CofradeoNetworkImage(
                            url: imageUrl,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.zero,
                          )
                        else
                          ColoredBox(
                            color: AppColors.burgundy.withValues(alpha: 0.06),
                            child: Icon(
                              meta.icon,
                              size: 36,
                              color: AppColors.burgundy.withValues(alpha: 0.55),
                            ),
                          ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0x59000000)],
                              stops: [0.5, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: _CategoryPill(meta: meta, onDark: hasImage),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HermandadByline(
                            topic: boardTopic,
                            timeAgo: reply.timeAgo,
                            compact: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            parsed.title,
                            style: AppTypography.hermandadName().copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showBody) ...[
                            const SizedBox(height: 4),
                            Text(
                              parsed.body,
                              style: AppTypography.bodyMedium(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 11.5, height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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

class _ManageMini extends StatelessWidget {
  const _ManageMini({required this.options});

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
                  ? 'Quitar fijado'
                  : 'Fijar arriba del tablón',
            ),
          ),
        if (options.canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }
}

({String title, String body}) _parseOfficialContent(String raw) {
  var text = raw.trim();
  if (text.isEmpty) {
    return (title: 'Comunicado oficial', body: '');
  }

  // Quita énfasis markdown sin aplastar saltos de línea.
  text = text.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*', dotAll: true),
    (m) => m.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'_(.+?)_'),
    (m) => m.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  if (lines.isEmpty) {
    return (title: 'Comunicado oficial', body: '');
  }

  final title = lines.first;
  final body = lines.skip(1).join('\n\n').trim();

  // Evita títulos absurdamente largos si no había salto.
  if (body.isEmpty && title.length > 90) {
    final cut = title.indexOf('. ');
    if (cut > 20 && cut < 90) {
      return (
        title: title.substring(0, cut + 1).trim(),
        body: title.substring(cut + 1).trim(),
      );
    }
  }

  return (title: title, body: body);
}

({String kicker, IconData icon}) _categoryMeta(String? category) {
  return switch (category) {
    'culto' => (kicker: 'CULTO', icon: Icons.church_outlined),
    'acto' => (kicker: 'ACTO', icon: Icons.event_outlined),
    'patrimonio' => (
        kicker: 'PATRIMONIO',
        icon: Icons.account_balance_outlined,
      ),
    'aviso' => (kicker: 'AVISO', icon: Icons.campaign_outlined),
    _ => (kicker: 'NOTICIA', icon: Icons.article_outlined),
  };
}
