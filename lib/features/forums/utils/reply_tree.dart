import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/forum.dart';
import '../topic_detail_typography.dart';
import '../widgets/hermandad_comunicado_card.dart';
import '../widgets/reply_card.dart';

/// A partir de este número de subrespuestas, el hilo se colapsa por defecto.
const kCollapsedThreadThreshold = 2;

/// Subrespuestas visibles en modo colapsado (la más reciente).
const kCollapsedThreadPreviewCount = 1;

String _normId(String? id) => id?.toLowerCase() ?? '';

int _replySortKey(ForumReply reply) =>
    reply.createdAt?.millisecondsSinceEpoch ?? 0;

List<ForumReply> filterVisibleReplies(List<ForumReply> replies) {
  return replies
      .where((r) => r.isDeleted || r.content.trim().isNotEmpty)
      .toList();
}

List<ReplyTreeNode> buildReplyTree(List<ForumReply> replies) {
  final visible = filterVisibleReplies(replies);
  final ids = visible.map((r) => _normId(r.id)).toSet();

  final byParent = <String, List<ForumReply>>{};
  final roots = <ForumReply>[];

  for (final reply in visible) {
    final parentId = _normId(reply.parentReplyId);
    if (parentId.isEmpty || !ids.contains(parentId)) {
      roots.add(reply);
      continue;
    }
    byParent.putIfAbsent(parentId, () => []).add(reply);
  }

  roots.sort((a, b) {
    if (a.isFeatured != b.isFeatured) {
      return a.isFeatured ? -1 : 1;
    }
    return _replySortKey(b).compareTo(_replySortKey(a));
  });

  for (final children in byParent.values) {
    children.sort((a, b) => _replySortKey(a).compareTo(_replySortKey(b)));
  }

  List<ReplyTreeNode> collectDescendants(ForumReply parent) {
    final directChildren = byParent[_normId(parent.id)] ?? [];
    final descendants = <ReplyTreeNode>[];

    for (final child in directChildren) {
      descendants.add(
        ReplyTreeNode(
          reply: child,
          depth: 1,
          parentHandle: parent.authorHandle,
          children: const [],
        ),
      );
      descendants.addAll(collectDescendants(child));
    }

    return descendants;
  }

  return [
    for (final root in roots)
      ReplyTreeNode(
        reply: root,
        depth: 0,
        parentHandle: null,
        children: collectDescendants(root),
      ),
  ];
}

class ReplyTreeNode {
  const ReplyTreeNode({
    required this.reply,
    required this.depth,
    required this.children,
    this.parentHandle,
  });

  final ForumReply reply;
  final int depth;
  final String? parentHandle;
  final List<ReplyTreeNode> children;
}

/// Índice del hilo raíz que contiene [replyId] (para scroll con lista virtualizada).
int? indexOfReplyRoot(List<ReplyTreeNode> nodes, String replyId) {
  final target = _normId(replyId);
  if (target.isEmpty) return null;
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (_normId(node.reply.id) == target) return i;
    if (node.children.any((c) => _normId(c.reply.id) == target)) return i;
  }
  return null;
}

class ReplyThreadList extends StatefulWidget {
  const ReplyThreadList({
    super.key,
    required this.nodes,
    this.onAuthorTap,
    this.onReplyTap,
    this.reactionCountsFor,
    this.userReactionFor,
    this.onReactionChanged,
    this.onReportTap,
    this.onShareTap,
    this.manageOptionsFor,
    this.showReport,
    this.highlightReplyId,
    this.replyAnchorKeys,
    this.topicAuthorId,
    /// Si true, construye un [SliverList] (solo hijos visibles).
    this.sliver = false,
    /// Canal oficial: cards tipo periódico en vez de reply de foro.
    this.officialChannelStyle = false,
    /// Abrir comunicado oficial a pantalla casi completa.
    this.onOfficialOpen,
  });

  final List<ReplyTreeNode> nodes;
  final void Function(ForumReply reply)? onAuthorTap;
  final void Function(ForumReply reply)? onReplyTap;
  final Map<String, int> Function(ForumReply reply)? reactionCountsFor;
  final String? Function(ForumReply reply)? userReactionFor;
  final Future<void> Function(ForumReply reply, String? reaction)?
      onReactionChanged;
  final void Function(ForumReply reply)? onReportTap;
  final void Function(ForumReply reply)? onShareTap;
  final ReplyManageOptions? Function(ForumReply reply)? manageOptionsFor;
  final bool Function(ForumReply reply)? showReport;
  final String? highlightReplyId;
  final Map<String, GlobalKey>? replyAnchorKeys;
  final String? topicAuthorId;
  final bool sliver;
  final bool officialChannelStyle;
  final void Function(ForumReply reply)? onOfficialOpen;

  @override
  State<ReplyThreadList> createState() => _ReplyThreadListState();
}

class _ReplyThreadListState extends State<ReplyThreadList> {
  late final Set<String> _expandedThreadIds;

  @override
  void initState() {
    super.initState();
    _expandedThreadIds = _initialExpandedThreads(
      widget.nodes,
      widget.highlightReplyId,
    );
  }

  @override
  void didUpdateWidget(covariant ReplyThreadList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightReplyId != widget.highlightReplyId) {
      _expandedThreadIds.addAll(
        _initialExpandedThreads(widget.nodes, widget.highlightReplyId),
      );
    }
  }

  Set<String> _initialExpandedThreads(
    List<ReplyTreeNode> nodes,
    String? highlightReplyId,
  ) {
    if (highlightReplyId == null) return {};

    final highlight = _normId(highlightReplyId);
    final expanded = <String>{};

    for (final node in nodes) {
      if (node.children.length < kCollapsedThreadThreshold) continue;
      final containsHighlight = node.children.any(
        (child) => _normId(child.reply.id) == highlight,
      );
      if (containsHighlight) {
        expanded.add(_normId(node.reply.id));
      }
    }

    return expanded;
  }

  void _toggleThread(String replyId) {
    final id = _normId(replyId);
    setState(() {
      if (_expandedThreadIds.contains(id)) {
        _expandedThreadIds.remove(id);
      } else {
        _expandedThreadIds.add(id);
      }
    });
  }

  Widget _rootThread(int i) {
    final node = widget.nodes[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReplyCardSlot(
          node: node,
          topicAuthorId: widget.topicAuthorId,
          replyAnchorKeys: widget.replyAnchorKeys,
          highlightReplyId: widget.highlightReplyId,
          onAuthorTap: widget.onAuthorTap,
          onReplyTap: widget.onReplyTap,
          reactionCountsFor: widget.reactionCountsFor,
          userReactionFor: widget.userReactionFor,
          onReactionChanged: widget.onReactionChanged,
          onReportTap: widget.onReportTap,
          onShareTap: widget.onShareTap,
          manageOptionsFor: widget.manageOptionsFor,
          showReport: widget.showReport,
          officialChannelStyle: widget.officialChannelStyle,
          onOfficialOpen: widget.onOfficialOpen,
        ),
        if (node.children.isNotEmpty && !widget.officialChannelStyle)
          _ReplyThreadBranch(
            children: node.children,
            expanded: _expandedThreadIds.contains(_normId(node.reply.id)),
            onToggle: () => _toggleThread(node.reply.id),
            topicAuthorId: widget.topicAuthorId,
            replyAnchorKeys: widget.replyAnchorKeys,
            highlightReplyId: widget.highlightReplyId,
            onAuthorTap: widget.onAuthorTap,
            onReplyTap: widget.onReplyTap,
            reactionCountsFor: widget.reactionCountsFor,
            userReactionFor: widget.userReactionFor,
            onReactionChanged: widget.onReactionChanged,
            onReportTap: widget.onReportTap,
            onShareTap: widget.onShareTap,
            manageOptionsFor: widget.manageOptionsFor,
            showReport: widget.showReport,
          ),
      ],
    );
  }

  Widget _divider() {
    if (widget.officialChannelStyle) {
      return const SizedBox(height: 10);
    }
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border.withValues(alpha: 0.55),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return widget.sliver
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : const SizedBox.shrink();
    }

    if (widget.sliver) {
      return SliverList.separated(
        itemCount: widget.nodes.length,
        separatorBuilder: (_, _) => _divider(),
        itemBuilder: (context, i) => _rootThread(i),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.nodes.length; i++) ...[
          _rootThread(i),
          if (i < widget.nodes.length - 1) _divider(),
        ],
      ],
    );
  }
}

class _ReplyThreadBranch extends StatelessWidget {
  const _ReplyThreadBranch({
    required this.children,
    required this.expanded,
    required this.onToggle,
    this.replyAnchorKeys,
    this.highlightReplyId,
    this.onAuthorTap,
    this.onReplyTap,
    this.reactionCountsFor,
    this.userReactionFor,
    this.onReactionChanged,
    this.onReportTap,
    this.onShareTap,
    this.manageOptionsFor,
    this.showReport,
    this.topicAuthorId,
  });

  final List<ReplyTreeNode> children;
  final bool expanded;
  final VoidCallback onToggle;
  final Map<String, GlobalKey>? replyAnchorKeys;
  final String? highlightReplyId;
  final String? topicAuthorId;
  final void Function(ForumReply reply)? onAuthorTap;
  final void Function(ForumReply reply)? onReplyTap;
  final Map<String, int> Function(ForumReply reply)? reactionCountsFor;
  final String? Function(ForumReply reply)? userReactionFor;
  final Future<void> Function(ForumReply reply, String? reaction)?
      onReactionChanged;
  final void Function(ForumReply reply)? onReportTap;
  final void Function(ForumReply reply)? onShareTap;
  final ReplyManageOptions? Function(ForumReply reply)? manageOptionsFor;
  final bool Function(ForumReply reply)? showReport;

  bool get _isCollapsible => children.length >= kCollapsedThreadThreshold;

  List<ReplyTreeNode> get _visibleChildren {
    if (!_isCollapsible || expanded) return children;
    if (kCollapsedThreadPreviewCount <= 0) return const [];
    final previewCount = kCollapsedThreadPreviewCount.clamp(0, children.length);
    return children.sublist(children.length - previewCount);
  }

  int get _hiddenCount {
    if (!_isCollapsible || expanded) return 0;
    return children.length - _visibleChildren.length;
  }

  @override
  Widget build(BuildContext context) {
    // Estilo X: sin riel lateral ni sangría fuerte. El contexto va
    // en "Respondiendo a @…" dentro de cada reply.
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 0, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isCollapsible && !expanded && _hiddenCount > 0)
            _ThreadToggleButton(
              label: _hiddenCount == 1
                  ? 'Mostrar 1 respuesta'
                  : 'Mostrar $_hiddenCount respuestas',
              expanded: false,
              onPressed: onToggle,
            ),
          for (var i = 0; i < _visibleChildren.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withValues(alpha: 0.35),
              ),
            _ReplyCardSlot(
              node: _visibleChildren[i],
              topicAuthorId: topicAuthorId,
              replyAnchorKeys: replyAnchorKeys,
              highlightReplyId: highlightReplyId,
              onAuthorTap: onAuthorTap,
              onReplyTap: onReplyTap,
              reactionCountsFor: reactionCountsFor,
              userReactionFor: userReactionFor,
              onReactionChanged: onReactionChanged,
              onReportTap: onReportTap,
              onShareTap: onShareTap,
              manageOptionsFor: manageOptionsFor,
              showReport: showReport,
            ),
          ],
          if (_isCollapsible && expanded)
            _ThreadToggleButton(
              label: 'Ocultar respuestas',
              expanded: true,
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}

class _ThreadToggleButton extends StatelessWidget {
  const _ThreadToggleButton({
    required this.label,
    required this.onPressed,
    required this.expanded,
  });

  final String label;
  final VoidCallback onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TopicDetailTypography.meta(
                  color: AppColors.burgundy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.burgundy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyCardSlot extends StatelessWidget {
  const _ReplyCardSlot({
    required this.node,
    this.topicAuthorId,
    this.replyAnchorKeys,
    this.highlightReplyId,
    this.onAuthorTap,
    this.onReplyTap,
    this.reactionCountsFor,
    this.userReactionFor,
    this.onReactionChanged,
    this.onReportTap,
    this.onShareTap,
    this.manageOptionsFor,
    this.showReport,
    this.officialChannelStyle = false,
    this.onOfficialOpen,
  });

  final ReplyTreeNode node;
  final String? topicAuthorId;
  final Map<String, GlobalKey>? replyAnchorKeys;
  final String? highlightReplyId;
  final void Function(ForumReply reply)? onAuthorTap;
  final void Function(ForumReply reply)? onReplyTap;
  final Map<String, int> Function(ForumReply reply)? reactionCountsFor;
  final String? Function(ForumReply reply)? userReactionFor;
  final Future<void> Function(ForumReply reply, String? reaction)?
      onReactionChanged;
  final void Function(ForumReply reply)? onReportTap;
  final void Function(ForumReply reply)? onShareTap;
  final ReplyManageOptions? Function(ForumReply reply)? manageOptionsFor;
  final bool Function(ForumReply reply)? showReport;
  final bool officialChannelStyle;
  final void Function(ForumReply reply)? onOfficialOpen;

  bool get _isTopicAuthor {
    final authorId = topicAuthorId;
    final replyAuthorId = node.reply.authorId;
    if (authorId == null || replyAuthorId == null) return false;
    return _normId(authorId) == _normId(replyAuthorId);
  }

  @override
  Widget build(BuildContext context) {
    final reply = node.reply;
    if (officialChannelStyle && reply.isOfficial) {
      return Padding(
        padding: EdgeInsets.zero,
        key: replyAnchorKeys?.putIfAbsent(
          _normId(reply.id),
          GlobalKey.new,
        ),
        child: HermandadComunicadoCard(
          key: ValueKey(reply.id),
          reply: reply,
          manageOptions: manageOptionsFor?.call(reply),
          onShareTap: onShareTap != null && !reply.isDeleted
              ? () => onShareTap!(reply)
              : null,
          reactionCounts: reactionCountsFor?.call(reply) ?? const {},
          userReaction: userReactionFor?.call(reply),
          onReactionChanged: onReactionChanged != null
              ? (reaction) => onReactionChanged!(reply, reaction)
              : null,
          onOpen: onOfficialOpen != null ? () => onOfficialOpen!(reply) : null,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.zero,
      key: replyAnchorKeys?.putIfAbsent(
        _normId(reply.id),
        GlobalKey.new,
      ),
      child: ReplyCard(
        key: ValueKey(reply.id),
        reply: reply,
        depth: node.depth,
        parentHandle: node.parentHandle,
        highlighted: highlightReplyId != null &&
            _normId(highlightReplyId) == _normId(reply.id),
        isTopicAuthor: _isTopicAuthor,
        reactionCounts: reactionCountsFor?.call(reply) ?? const {},
        userReaction: userReactionFor?.call(reply),
        onReactionChanged: onReactionChanged != null
            ? (reaction) => onReactionChanged!(reply, reaction)
            : null,
        onAuthorTap:
            onAuthorTap != null ? () => onAuthorTap!(reply) : null,
        onReplyTap: onReplyTap != null ? () => onReplyTap!(reply) : null,
        onShareTap: onShareTap != null && !reply.isDeleted
            ? () => onShareTap!(reply)
            : null,
        onReportTap: onReportTap != null &&
                (showReport?.call(reply) ?? true) &&
                !reply.isDeleted
            ? () => onReportTap!(reply)
            : null,
        manageOptions: manageOptionsFor?.call(reply),
      ),
    );
  }
}
