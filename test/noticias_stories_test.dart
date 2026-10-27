import 'package:cofradeo/features/forums/utils/noticias_stories.dart';
import 'package:cofradeo/shared/models/forum.dart';
import 'package:flutter_test/flutter_test.dart';

ForumTopic _topic({
  required String id,
  required DateTime createdAt,
  String? newsGroupId,
  String title = 'Noticia',
}) {
  return ForumTopic(
    id: id,
    forumId: 'noticias',
    title: title,
    excerpt: 'extracto',
    body: 'cuerpo',
    authorHandle: '@cuenta',
    timeAgo: 'ahora',
    commentCount: 0,
    viewCount: 0,
    createdAt: createdAt,
    newsGroupId: newsGroupId,
  );
}

void main() {
  test('una noticia suelta sigue siendo una ficha', () {
    final stories = groupNoticiasForFeed([
      _topic(id: 'a', createdAt: DateTime(2026, 3, 1)),
    ]);

    expect(stories, hasLength(1));
    expect(stories.single.isGrouped, isFalse);
    expect(stories.single.lead.id, 'a');
  });

  test('el carrusel ordena por llegada y el listado por la más reciente', () {
    final early = DateTime(2026, 3, 1, 10);
    final late = DateTime(2026, 3, 1, 12);
    final stories = groupNoticiasForFeed([
      _topic(id: 'nueva-suelta', createdAt: DateTime(2026, 3, 1, 11)),
      _topic(id: 'segunda', createdAt: late, newsGroupId: 'g1'),
      _topic(id: 'primera', createdAt: early, newsGroupId: 'g1'),
    ]);

    expect(stories, hasLength(2));
    expect(stories.first.lead.id, 'primera');
    expect(stories.first.topics.map((t) => t.id), ['primera', 'segunda']);
    expect(stories.last.lead.id, 'nueva-suelta');
  });

  test('el detalle incluye a la noticia abierta aunque el listado no la traiga', () {
    final opened = _topic(
      id: 'abierta',
      createdAt: DateTime(2026, 3, 2),
      newsGroupId: 'g1',
    );
    final story = storyForTopic(
      [
        _topic(
          id: 'otra',
          createdAt: DateTime(2026, 3, 1),
          newsGroupId: 'g1',
        ),
      ],
      opened,
    );

    expect(story.topics.map((t) => t.id), ['otra', 'abierta']);
  });
}
