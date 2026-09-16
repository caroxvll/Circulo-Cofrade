import 'package:flutter_test/flutter_test.dart';
import 'package:cofradeo/core/constants/app_branding.dart';
import 'package:cofradeo/core/utils/forum_share_urls.dart';

void main() {
  test('buildForumTopicShareUrl usa origen https absoluto', () {
    final url = buildForumTopicShareUrl(
      forumId: 'foro-1',
      topicId: 'tema-2',
    );
    expect(url, '${AppBranding.webOrigin}/foros/foro-1/tema/tema-2');
  });

  test('buildForumTopicShareUrl incluye reply y seccion', () {
    final url = buildForumTopicShareUrl(
      forumId: 'foro-1',
      topicId: 'tema-2',
      section: 'culto',
      replyId: 'r-9',
    );
    expect(url, contains('/foros/foro-1/tema/tema-2?'));
    expect(url, contains('reply=r-9'));
    expect(url, startsWith(AppBranding.webOrigin));
  });
}
