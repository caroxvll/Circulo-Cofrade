import 'package:flutter_test/flutter_test.dart';
import 'package:cofradeo/features/forums/utils/noticias_forum.dart';

void main() {
  test('etiquetas temáticas de noticias', () {
    expect(isValidNoticiasCategory('musica'), isTrue);
    expect(isValidNoticiasCategory('consejo'), isTrue);
    expect(isValidNoticiasCategory('noticias'), isFalse);
    expect(isValidNoticiasCategory(null), isFalse);
    expect(noticiasCategoryIds, contains('hermandades'));
    expect(noticiasCategoryLabel('musica'), 'Música');
    expect(noticiasCategoryLabel('pentagrama-cofrade'), 'Música');
  });
}
