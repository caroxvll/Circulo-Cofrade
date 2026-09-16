import 'package:cofradeo/features/forums/utils/reply_tree.dart';
import 'package:cofradeo/shared/models/forum.dart';
import 'package:flutter_test/flutter_test.dart';

ForumReply _reply({
  required String id,
  String? parentReplyId,
  DateTime? createdAt,
}) {
  return ForumReply(
    id: id,
    topicId: 'topic-1',
    authorHandle: id,
    timeAgo: 'ahora',
    content: 'contenido $id',
    commentCount: 0,
    likeCount: 0,
    parentReplyId: parentReplyId,
    createdAt: createdAt,
  );
}

void main() {
  group('buildReplyTree', () {
    test('agrupa subrespuestas bajo la raíz a profundidad visual 1', () {
      final tree = buildReplyTree([
        _reply(id: 'root', createdAt: DateTime(2026, 1, 1)),
        _reply(
          id: 'child',
          parentReplyId: 'root',
          createdAt: DateTime(2026, 1, 2),
        ),
        _reply(
          id: 'grandchild',
          parentReplyId: 'child',
          createdAt: DateTime(2026, 1, 3),
        ),
      ]);

      expect(tree, hasLength(1));
      expect(tree.first.reply.id, 'root');
      expect(tree.first.children, hasLength(2));
      expect(tree.first.children.map((n) => n.reply.id), ['child', 'grandchild']);
      expect(tree.first.children.every((n) => n.depth == 1), isTrue);
      expect(tree.first.children.first.parentHandle, 'root');
      expect(tree.first.children.last.parentHandle, 'child');
    });

    test('ordena subrespuestas cronológicamente', () {
      final tree = buildReplyTree([
        _reply(id: 'root'),
        _reply(
          id: 'older',
          parentReplyId: 'root',
          createdAt: DateTime(2026, 1, 1),
        ),
        _reply(
          id: 'newer',
          parentReplyId: 'root',
          createdAt: DateTime(2026, 1, 2),
        ),
      ]);

      expect(
        tree.first.children.map((n) => n.reply.id),
        ['older', 'newer'],
      );
    });
  });
}
