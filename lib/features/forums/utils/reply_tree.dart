import 'package:flutter/material.dart';



import '../../../shared/models/forum.dart';

import '../widgets/reply_card.dart';



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



  roots.sort((a, b) => _replySortKey(b).compareTo(_replySortKey(a)));

  for (final children in byParent.values) {

    children.sort((a, b) => _replySortKey(a).compareTo(_replySortKey(b)));

  }



  List<ReplyTreeNode> walk(ForumReply reply, int depth, String? parentHandle) {

    final children = byParent[_normId(reply.id)] ?? [];

    return [

      ReplyTreeNode(

        reply: reply,

        depth: depth,

        parentHandle: parentHandle,

        children: [

          for (final child in children)

            ...walk(child, depth + 1, reply.authorHandle),

        ],

      ),

    ];

  }



  return [

    for (final root in roots) ...walk(root, 0, null),

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



class ReplyThreadList extends StatelessWidget {

  const ReplyThreadList({

    super.key,

    required this.nodes,

    this.onAuthorTap,

    this.onReplyTap,

    this.isLiked,

    this.onLikeTap,

    this.onReportTap,

    this.manageOptionsFor,

    this.showReport,

    this.highlightReplyId,

    this.replyAnchorKeys,

  });



  final List<ReplyTreeNode> nodes;

  final void Function(ForumReply reply)? onAuthorTap;

  final void Function(ForumReply reply)? onReplyTap;

  final bool Function(ForumReply reply)? isLiked;

  final void Function(ForumReply reply)? onLikeTap;

  final void Function(ForumReply reply)? onReportTap;

  final ReplyManageOptions? Function(ForumReply reply)? manageOptionsFor;

  final bool Function(ForumReply reply)? showReport;

  final String? highlightReplyId;

  final Map<String, GlobalKey>? replyAnchorKeys;



  @override

  Widget build(BuildContext context) {

    final flat = <ReplyTreeNode>[];

    _flatten(nodes, flat);



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        for (final node in flat)

          Padding(

            padding: const EdgeInsets.only(bottom: 10),

            key: replyAnchorKeys?.putIfAbsent(
              _normId(node.reply.id),
              GlobalKey.new,
            ),

            child: ReplyCard(

              key: ValueKey(node.reply.id),

              reply: node.reply,

              depth: node.depth,

              parentHandle: node.parentHandle,

              highlighted: highlightReplyId != null &&
                  _normId(highlightReplyId) == _normId(node.reply.id),

              isLiked: isLiked?.call(node.reply) ?? false,

              onAuthorTap: onAuthorTap != null

                  ? () => onAuthorTap!(node.reply)

                  : null,

              onReplyTap:

                  onReplyTap != null ? () => onReplyTap!(node.reply) : null,

              onLikeTap:

                  onLikeTap != null ? () => onLikeTap!(node.reply) : null,

              onReportTap: onReportTap != null &&
                      (showReport?.call(node.reply) ?? true) &&
                      !node.reply.isDeleted
                  ? () => onReportTap!(node.reply)
                  : null,

              manageOptions: manageOptionsFor?.call(node.reply),

            ),

          ),

      ],

    );

  }



  void _flatten(List<ReplyTreeNode> nodes, List<ReplyTreeNode> out) {

    for (final node in nodes) {

      out.add(node);

      _flatten(node.children, out);

    }

  }

}

