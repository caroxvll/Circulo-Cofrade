import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import 'forum_post_image_viewer.dart';
import 'reply_card.dart';

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
  });

  final ForumReply reply;
  final ReplyManageOptions? manageOptions;
  final VoidCallback? onShareTap;
  final Map<String, int> reactionCounts;
  final String? userReaction;
  final Future<void> Function(String? reaction)? onReactionChanged;
  final bool detailView;
  final VoidCallback? onOpen;

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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(meta.icon, size: 12, color: AppColors.burgundy),
                        const SizedBox(width: 4),
                        Text(
                          meta.kicker,
                          style: AppTypography.labelSmall(
                            color: AppColors.burgundy,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    reply.timeAgo,
                    style: AppTypography.labelSmall(
                      color: AppColors.textMuted,
                    ).copyWith(fontSize: 11),
                  ),
                  if (widget.manageOptions != null)
                    _ManageMini(options: widget.manageOptions!),
                ],
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
                          if (parsed.body.isNotEmpty) ...[
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
  });

  final ForumReply reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseOfficialContent(reply.content);
    final meta = _categoryMeta(reply.officialCategory);
    final imageUrl = reply.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return SizedBox(
      width: 196,
      height: 248,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 1.5,
        shadowColor: AppColors.burgundyDark.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 104,
                    child: hasImage
                        ? CofradeoNetworkImage(
                            url: imageUrl,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.zero,
                          )
                        : ColoredBox(
                            color: AppColors.burgundy.withValues(alpha: 0.06),
                            child: Icon(
                              meta.icon,
                              size: 36,
                              color: AppColors.burgundy.withValues(alpha: 0.55),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.burgundy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            meta.kicker,
                            style: AppTypography.labelSmall(
                              color: AppColors.burgundy,
                            ).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          parsed.title,
                          style: AppTypography.hermandadName().copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (parsed.body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            parsed.body,
                            style: AppTypography.bodyMedium(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 11, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
                        Text(
                          reply.timeAgo,
                          style: AppTypography.labelSmall(
                            color: AppColors.textMuted,
                          ).copyWith(fontSize: 10),
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
