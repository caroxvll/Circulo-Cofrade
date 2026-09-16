import 'package:cofradeo/core/utils/forum_topic_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildForumTopicQuery', () {
    test('vacío sin parámetros', () {
      expect(buildForumTopicQuery(), '');
    });

    test('sección hermandad', () {
      expect(
        buildForumTopicQuery(section: 'culto'),
        '?seccion=cultos',
      );
    });

    test('reply y sección combinados', () {
      expect(
        buildForumTopicQuery(section: 'acto', replyId: 'abc-123'),
        '?seccion=actos&reply=abc-123',
      );
    });

    test('aprobado', () {
      expect(buildForumTopicQuery(approved: true), '?aprobado=1');
    });
  });
}
