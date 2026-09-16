import 'package:flutter_test/flutter_test.dart';
import 'package:cofradeo/features/forums/utils/noticias_forum.dart';

void main() {
  test('foros relacionados válidos para noticias', () {
    expect(isValidNoticiasRelatedForum('pentagrama-cofrade'), isTrue);
    expect(isValidNoticiasRelatedForum('noticias'), isFalse);
    expect(isValidNoticiasRelatedForum(null), isFalse);
    expect(noticiasRelatedForumIds, contains('hermandades'));
  });
}
