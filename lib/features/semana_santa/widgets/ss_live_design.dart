import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../auth/auth_provider.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/utils/reply_reactions.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';

/// Colores de tipo: semáforo cofrade (legibles sobre beige).
/// Retraso = ámbar (espera) · Incidencia = rojo alerta · Recorrido = burdeos marca.
Color ssKindColor(SsLiveUpdateKind kind) => switch (kind) {
      SsLiveUpdateKind.retraso => const Color(0xFFB45309), // ámbar oscuro
      SsLiveUpdateKind.posicion => AppColors.burgundy, // burdeos
      SsLiveUpdateKind.incidente => const Color(0xFF9B1C1C), // rojo alerta
      SsLiveUpdateKind.curiosidad => AppColors.goldDark, // dorado
      SsLiveUpdateKind.general => const Color(0xFF5C5652), // gris cálido
    };

IconData ssKindIcon(SsLiveUpdateKind kind) => switch (kind) {
      SsLiveUpdateKind.retraso => Icons.schedule_rounded,
      SsLiveUpdateKind.posicion => Icons.place_outlined,
      SsLiveUpdateKind.incidente => Icons.warning_amber_rounded,
      SsLiveUpdateKind.curiosidad => Icons.auto_awesome_outlined,
      SsLiveUpdateKind.general => Icons.campaign_outlined,
    };

const _emojiStyle = TextStyle(
  fontSize: 13,
  height: 1,
  fontFamily: 'Segoe UI Emoji',
  fontFamilyFallback: [
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Twemoji Mozilla',
  ],
);

class SsKindChip extends StatelessWidget {
  const SsKindChip({
    super.key,
    required this.kind,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  final SsLiveUpdateKind kind;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = ssKindColor(kind);
    final bg = selected ? color.withValues(alpha: 0.14) : AppColors.backgroundElevated;
    final border = selected ? color.withValues(alpha: 0.45) : AppColors.border;

    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ssKindIcon(kind), size: compact ? 12 : 14, color: color),
          SizedBox(width: compact ? 4 : 5),
          Text(
            kind.label,
            style: TopicDetailTypography.meta(
              color: color,
              fontWeight: FontWeight.w700,
            ).copyWith(fontSize: compact ? 11 : 12),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: child,
    );
  }
}

class SsLiveUpdateTile extends ConsumerStatefulWidget {
  const SsLiveUpdateTile({
    super.key,
    required this.update,
    this.isLatest = false,
  });

  final SsLiveUpdate update;
  final bool isLatest;

  @override
  ConsumerState<SsLiveUpdateTile> createState() => _SsLiveUpdateTileState();
}

class _SsLiveUpdateTileState extends ConsumerState<SsLiveUpdateTile> {
  var _repliesOpen = false;
  var _postingReply = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _setReaction(String? reaction) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(ssLiveEngagementRepositoryProvider).setReaction(
          userId: user.id,
          updateId: widget.update.id,
          reaction: reaction,
        );
    ref.invalidate(ssLiveEngagementProvider);
  }

  Future<void> _submitReply() async {
    final user = ref.read(currentUserProvider);
    final text = _replyController.text.trim();
    if (user == null || text.isEmpty || _postingReply) return;

    setState(() => _postingReply = true);
    try {
      await ref.read(ssLiveEngagementRepositoryProvider).postReply(
            userId: user.id,
            updateId: widget.update.id,
            message: text,
          );
      _replyController.clear();
      ref.invalidate(ssLiveRepliesProvider(widget.update.id));
      ref.invalidate(ssLiveEngagementProvider);
    } finally {
      if (mounted) setState(() => _postingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final hermandad = update.hermandadLabel?.trim();
    final place = update.placeLabel?.trim();
    final color = ssKindColor(update.kind);
    final engagement = ref.watch(ssLiveEngagementProvider).asData?.value;
    final counts = engagement?.countsFor(update.id) ?? const <String, int>{};
    final userReaction = engagement?.userReactionFor(update.id);
    final replyCount = engagement?.replyCountFor(update.id) ?? 0;
    final canEngage = ref.watch(currentUserProvider) != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: widget.isLatest
            ? AppColors.burgundy.withValues(alpha: 0.03)
            : AppColors.backgroundElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isLatest
              ? AppColors.burgundy.withValues(alpha: 0.16)
              : AppColors.border.withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CofradeoAvatar(
                imageUrl: update.authorAvatarUrl,
                size: 36,
                backgroundColor: AppColors.backgroundElevated,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            update.authorHandle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TopicDetailTypography.body().copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatTimeAgo(update.createdAt),
                          style: TopicDetailTypography.meta().copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(ssKindIcon(update.kind), size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(
                          update.kind.label,
                          style: TopicDetailTypography.meta(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hermandad != null && hermandad.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              hermandad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TopicDetailTypography.body().copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            update.message,
            softWrap: true,
            style: TopicDetailTypography.body().copyWith(
              height: 1.35,
              fontSize: 13.5,
            ),
          ),
          if (place != null && place.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TopicDetailTypography.meta(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _SsReactionsBar(
                  reactionCounts: counts,
                  userReaction: userReaction,
                  enabled: canEngage,
                  onReactionChanged: canEngage ? _setReaction : null,
                ),
              ),
              const SizedBox(width: 4),
              _ReplyToggle(
                count: replyCount,
                open: _repliesOpen,
                onTap: () => setState(() => _repliesOpen = !_repliesOpen),
              ),
            ],
          ),
          if (_repliesOpen) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _SsRepliesPanel(
              updateId: update.id,
              controller: _replyController,
              posting: _postingReply,
              canPost: canEngage,
              onSubmit: _submitReply,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyToggle extends StatelessWidget {
  const _ReplyToggle({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: open
          ? AppColors.burgundy.withValues(alpha: 0.08)
          : AppColors.backgroundElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                open ? Icons.chat_bubble : Icons.chat_bubble_outline,
                size: 15,
                color: open ? AppColors.burgundy : AppColors.textSecondary,
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TopicDetailTypography.meta(
                    color: open ? AppColors.burgundy : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SsRepliesPanel extends ConsumerWidget {
  const _SsRepliesPanel({
    required this.updateId,
    required this.controller,
    required this.posting,
    required this.canPost,
    required this.onSubmit,
  });

  final String updateId;
  final TextEditingController controller;
  final bool posting;
  final bool canPost;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesAsync = ref.watch(ssLiveRepliesProvider(updateId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        repliesAsync.when(
          data: (replies) {
            if (replies.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sé el primero en responder.',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textMuted,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final reply in replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CofradeoAvatar(
                          imageUrl: reply.authorAvatarUrl,
                          size: 26,
                          backgroundColor: AppColors.backgroundElevated,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reply.authorHandle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TopicDetailTypography.meta(
                                        fontWeight: FontWeight.w700,
                                      ).copyWith(fontSize: 11),
                                    ),
                                  ),
                                  Text(
                                    formatTimeAgo(reply.createdAt),
                                    style: TopicDetailTypography.meta()
                                        .copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reply.message,
                                style: TopicDetailTypography.body()
                                    .copyWith(fontSize: 12.5, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => Text(
            'No se pudieron cargar las respuestas.',
            style: TopicDetailTypography.meta(color: AppColors.textSecondary),
          ),
        ),
        if (canPost)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLength: 280,
                  minLines: 1,
                  maxLines: 3,
                  enabled: !posting,
                  style: TopicDetailTypography.body().copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Escribe una respuesta…',
                    hintStyle: TopicDetailTypography.meta(
                      color: AppColors.textMuted,
                    ),
                    isDense: true,
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: posting ? null : onSubmit,
                icon: posting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                color: AppColors.burgundy,
                visualDensity: VisualDensity.compact,
              ),
            ],
          )
        else
          Text(
            'Inicia sesión para responder.',
            style: TopicDetailTypography.meta(color: AppColors.textMuted),
          ),
      ],
    );
  }
}

class _SsReactionsBar extends StatefulWidget {
  const _SsReactionsBar({
    required this.reactionCounts,
    required this.userReaction,
    required this.enabled,
    this.onReactionChanged,
  });

  final Map<String, int> reactionCounts;
  final String? userReaction;
  final bool enabled;
  final Future<void> Function(String? reaction)? onReactionChanged;

  @override
  State<_SsReactionsBar> createState() => _SsReactionsBarState();
}

class _SsReactionsBarState extends State<_SsReactionsBar> {
  var _hasOptimistic = false;
  String? _optimisticReaction;
  Map<String, int>? _optimisticCounts;
  var _submitting = false;
  var _pickerOpen = false;

  @override
  void didUpdateWidget(_SsReactionsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasOptimistic) return;
    final userSynced = reactionsEqual(widget.userReaction, _optimisticReaction);
    final countsSynced = _optimisticCounts == null ||
        mapEquals(
          normalizeReactionCounts(widget.reactionCounts),
          _optimisticCounts,
        );
    if (userSynced && countsSynced) {
      _hasOptimistic = false;
      _optimisticReaction = null;
      _optimisticCounts = null;
    }
  }

  Map<String, int> get _counts =>
      _optimisticCounts ?? normalizeReactionCounts(widget.reactionCounts);

  String? get _active =>
      _hasOptimistic ? _optimisticReaction : widget.userReaction;

  Future<void> _onReact(String emoji) async {
    if (!widget.enabled || widget.onReactionChanged == null || _submitting) {
      return;
    }
    final previous = _active;
    final next = reactionsEqual(emoji, previous) ? null : emoji;
    setState(() {
      _pickerOpen = false;
      _hasOptimistic = true;
      _optimisticReaction = next;
      final counts = Map<String, int>.from(_counts);
      if (previous != null) {
        final key = replyReactionDisplay(previous);
        final n = (counts[key] ?? 0) - 1;
        if (n <= 0) {
          counts.remove(key);
        } else {
          counts[key] = n;
        }
      }
      if (next != null) {
        final key = replyReactionDisplay(next);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      _optimisticCounts = counts;
      _submitting = true;
    });
    try {
      await widget.onReactionChanged!(next);
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasOptimistic = false;
          _optimisticReaction = null;
          _optimisticCounts = null;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_submitting;
    final active = sortedReactionCounts(_counts);
    final hasActivity = active.isNotEmpty;

    if (_pickerOpen) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final reaction in quickReplyReactions)
            _SsReactionPill(
              emoji: reaction.emoji,
              count: _counts[reaction.emoji] ?? 0,
              selected: reactionsEqual(reaction.emoji, _active),
              showCount: false,
              enabled: enabled,
              onTap: () => _onReact(reaction.emoji),
            ),
          _reactButton(open: true),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in active)
          _SsReactionPill(
            emoji: entry.key,
            count: entry.value,
            selected: reactionsEqual(entry.key, _active),
            showCount: true,
            enabled: enabled,
            onTap: () => _onReact(entry.key),
          ),
        if (hasActivity || widget.enabled) _reactButton(open: false),
      ],
    );
  }

  Widget _reactButton({required bool open}) {
    return IconButton(
      onPressed: widget.enabled
          ? () => setState(() => _pickerOpen = !_pickerOpen)
          : null,
      icon: Icon(
        open ? Icons.close : Icons.add_reaction_outlined,
        size: 18,
      ),
      color: AppColors.textMuted,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: open ? 'Cerrar' : 'Reaccionar',
    );
  }
}

class _SsReactionPill extends StatelessWidget {
  const _SsReactionPill({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.showCount,
    required this.enabled,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final bool showCount;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasCount = showCount && count > 0;
    return Material(
      color: selected
          ? AppColors.goldPale.withValues(alpha: 0.75)
          : hasCount
              ? AppColors.backgroundElevated
              : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: hasCount || selected ? 6 : 2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.6)
                  : hasCount
                      ? AppColors.border.withValues(alpha: 0.9)
                      : AppColors.border.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: _emojiStyle),
              if (hasCount) ...[
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: TopicDetailTypography.meta(
                    color: selected ? AppColors.goldDark : AppColors.textMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ).copyWith(fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SsLiveComposeBar extends StatelessWidget {
  const SsLiveComposeBar({
    super.key,
    required this.controller,
    required this.hermandadController,
    required this.placeController,
    required this.kind,
    required this.onKindChanged,
    required this.isPosting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final TextEditingController hermandadController;
  final TextEditingController placeController;
  final SsLiveUpdateKind kind;
  final ValueChanged<SsLiveUpdateKind> onKindChanged;
  final bool isPosting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in SsLiveUpdateKind.values)
                      SsKindChip(
                        kind: k,
                        selected: kind == k,
                        onTap: () => onKindChanged(k),
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hermandadController,
                  maxLength: 120,
                  style: TopicDetailTypography.body().copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Hermandad (opcional)',
                    hintStyle: TopicDetailTypography.meta(
                      color: AppColors.textMuted,
                    ),
                    isDense: true,
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: placeController,
                  maxLength: 160,
                  style: TopicDetailTypography.body().copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Lugar (opcional)',
                    hintStyle: TopicDetailTypography.meta(
                      color: AppColors.textMuted,
                    ),
                    isDense: true,
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLength: 280,
                        minLines: 1,
                        maxLines: 3,
                        style: TopicDetailTypography.body().copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '¿Qué está pasando ahora?',
                          hintStyle: TopicDetailTypography.meta(
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSubmit(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ComposeIconButton(
                      onTap: isPosting ? null : onSubmit,
                      isLoading: isPosting,
                      icon: Icons.send_rounded,
                      primary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposeIconButton extends StatelessWidget {
  const _ComposeIconButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.primary = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.burgundy : AppColors.backgroundElevated;
    final fg = primary ? Colors.white : AppColors.textSecondary;

    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}
