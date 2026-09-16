import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../topic_detail_typography.dart';
import '../utils/reply_reactions.dart';
import 'reply_reaction_users_sheet.dart';

const _emojiStyle = TextStyle(
  fontSize: 15,
  height: 1,
  fontFamily: 'Segoe UI Emoji',
  fontFamilyFallback: [
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Twemoji Mozilla',
  ],
);

const _emojiStyleCompact = TextStyle(
  fontSize: 13,
  height: 1,
  fontFamily: 'Segoe UI Emoji',
  fontFamilyFallback: [
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Twemoji Mozilla',
  ],
);

/// Compacto: contadores visibles; iconos al pulsar «Reaccionar».
class ReplyReactionsBar extends StatefulWidget {
  const ReplyReactionsBar({
    super.key,
    required this.replyId,
    required this.reactionCounts,
    this.userReaction,
    this.onReactionChanged,
    this.enabled = true,
    this.compact = false,
    this.alignEnd = false,
  });

  final String replyId;
  final Map<String, int> reactionCounts;
  final String? userReaction;
  final Future<void> Function(String? reaction)? onReactionChanged;
  final bool enabled;
  final bool compact;
  final bool alignEnd;

  @override
  State<ReplyReactionsBar> createState() => _ReplyReactionsBarState();
}

class _ReplyReactionsBarState extends State<ReplyReactionsBar> {
  /// Distingue «sin optimistic» de «optimistic = quitar reacción» (null).
  var _hasOptimistic = false;
  String? _optimisticReaction;
  Map<String, int>? _optimisticCounts;
  var _submitting = false;
  var _pickerOpen = false;

  @override
  void didUpdateWidget(ReplyReactionsBar oldWidget) {
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

  String? get _activeUserReaction =>
      _hasOptimistic ? _optimisticReaction : widget.userReaction;

  bool get _hasActivity => totalReactionCount(_counts) > 0;

  void _applyOptimisticCounts(String? previous, String? next) {
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
  }

  void _clearOptimistic() {
    _hasOptimistic = false;
    _optimisticReaction = null;
    _optimisticCounts = null;
  }

  Future<void> _onReact(String emoji) async {
    if (!widget.enabled || widget.onReactionChanged == null || _submitting) {
      return;
    }
    final previous = _activeUserReaction;
    final next = reactionsEqual(emoji, previous) ? null : emoji;
    setState(() {
      _pickerOpen = false;
      _hasOptimistic = true;
      _optimisticReaction = next;
      _applyOptimisticCounts(previous, next);
      _submitting = true;
    });
    try {
      await widget.onReactionChanged!(next);
    } catch (_) {
      if (mounted) {
        setState(_clearOptimistic);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showReactionUsers(String emoji) {
    showReplyReactionUsersSheet(
      context,
      replyId: widget.replyId,
      filterEmoji: emoji,
    );
  }

  Widget _reaccionarButton({bool compact = false}) {
    final small = compact || widget.compact;
    final iconSize = small ? 18.0 : 20.0;
    final isOpen = _pickerOpen;

    return IconButton(
      onPressed: widget.enabled
          ? () => setState(() => _pickerOpen = !_pickerOpen)
          : null,
      icon: Icon(
        isOpen ? Icons.close : Icons.add_reaction_outlined,
        size: iconSize,
      ),
      color: AppColors.textMuted,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: small ? 28 : 32,
        minHeight: small ? 28 : 32,
      ),
      tooltip: isOpen ? 'Cerrar reacciones' : 'Reaccionar',
    );
  }

  Widget _wrapBar(Widget child) {
    if (!widget.alignEnd) return child;
    return Align(
      alignment: Alignment.centerRight,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_submitting;
    final pillCompact = widget.compact;
    final spacing = pillCompact ? 4.0 : 5.0;

    if (_pickerOpen) {
      return _wrapBar(
        Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: widget.alignEnd ? WrapAlignment.end : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final reaction in quickReplyReactions)
              _ReactionPill(
                emoji: reaction.emoji,
                label: reaction.label,
                count: _counts[reaction.emoji] ?? 0,
                selected: reactionsEqual(reaction.emoji, _activeUserReaction),
                showCount: false,
                enabled: enabled,
                compact: pillCompact,
                onReact: () => _onReact(reaction.emoji),
              ),
            _reaccionarButton(compact: true),
          ],
        ),
      );
    }

    if (!_hasActivity) {
      return _wrapBar(_reaccionarButton(compact: pillCompact));
    }

    final active = sortedReactionCounts(_counts);

    return _wrapBar(
      Wrap(
        spacing: spacing,
        runSpacing: spacing,
        alignment: widget.alignEnd ? WrapAlignment.end : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final entry in active)
            _ReactionPill(
              emoji: entry.key,
              label: reactionLabel(entry.key),
              count: entry.value,
              selected: reactionsEqual(entry.key, _activeUserReaction),
              showCount: true,
              enabled: enabled,
              compact: pillCompact,
              onReact: () => _onReact(entry.key),
              onShowUsers: () => _showReactionUsers(entry.key),
            ),
          _reaccionarButton(compact: true),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.label,
    required this.count,
    required this.selected,
    required this.showCount,
    required this.enabled,
    required this.onReact,
    this.compact = false,
    this.onShowUsers,
  });

  final String emoji;
  final String label;
  final int count;
  final bool selected;
  final bool showCount;
  final bool enabled;
  final bool compact;
  final VoidCallback onReact;
  final VoidCallback? onShowUsers;

  bool get _hasCount => showCount && count > 0;

  @override
  Widget build(BuildContext context) {
    final tooltip = _hasCount
        ? '$label · $count · pulsa el número para ver quién reaccionó'
        : label;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Semantics(
        button: true,
        label: tooltip,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: _hasCount || selected ? (compact ? 6 : 8) : 0,
            vertical: compact ? 2 : 4,
          ),
          constraints: BoxConstraints(
            minWidth: compact ? 24 : 30,
            minHeight: compact ? 24 : 30,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? AppColors.goldPale.withValues(alpha: 0.75)
                : _hasCount
                    ? AppColors.backgroundElevated
                    : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.6)
                  : _hasCount
                      ? AppColors.border.withValues(alpha: 0.9)
                      : AppColors.border.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? onReact : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      emoji,
                      style: (compact ? _emojiStyleCompact : _emojiStyle).copyWith(
                        fontSize: compact
                            ? (_hasCount || selected ? 13 : 12)
                            : (_hasCount || selected ? 16 : 15),
                        color: _hasCount || selected
                            ? null
                            : AppColors.textMuted.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
              if (_hasCount) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: enabled ? onShowUsers : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2),
                      child: Text(
                        '$count',
                        style: TopicDetailTypography.meta(
                          color: selected
                              ? AppColors.goldDark
                              : AppColors.textMuted,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ).copyWith(fontSize: compact ? 10 : null),
                      ),
                    ),
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
