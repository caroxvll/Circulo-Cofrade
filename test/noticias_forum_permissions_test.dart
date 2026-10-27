import 'package:flutter_test/flutter_test.dart';
import 'package:cofradeo/features/forums/utils/topic_permissions.dart';

void main() {
  test('noticias solo la crea staff', () {
    expect(
      canCreateTopicInForum(
        forumId: 'noticias',
        isAdmin: true,
        moderatedForumIds: {},
      ),
      isTrue,
    );
    expect(
      canCreateTopicInForum(
        forumId: 'noticias',
        isAdmin: false,
        moderatedForumIds: {'noticias'},
      ),
      isTrue,
    );
    expect(
      canCreateTopicInForum(
        forumId: 'noticias',
        isAdmin: false,
        moderatedForumIds: {'foro-cofradiero'},
      ),
      isTrue,
    );
    expect(
      canCreateTopicInForum(
        forumId: 'noticias',
        isAdmin: false,
        moderatedForumIds: {},
        isNewsPublisher: true,
      ),
      isTrue,
    );
    expect(
      canCreateTopicInForum(
        forumId: 'noticias',
        isAdmin: false,
        moderatedForumIds: {},
        isCalendarContributor: true,
      ),
      isTrue,
    );
    expect(
      canCreateTopicInForum(
        forumId: 'noticias',
        isAdmin: false,
        moderatedForumIds: {},
      ),
      isFalse,
    );
  });

  test('foros normales siguen abiertos a miembros', () {
    expect(
      canCreateTopicInForum(
        forumId: 'foro-cofradiero',
        isAdmin: false,
        moderatedForumIds: {},
      ),
      isTrue,
    );
    expect(
      canCreateTopicInForum(
        forumId: 'hermandades',
        isAdmin: true,
        moderatedForumIds: {},
      ),
      isFalse,
    );
  });
}
