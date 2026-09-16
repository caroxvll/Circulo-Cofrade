import 'package:flutter_test/flutter_test.dart';

import 'package:cofradeo/features/forums/utils/official_post_categories.dart';

void main() {
  group('parseHermandadSectionQuery', () {
    test('accepts plural slugs', () {
      expect(parseHermandadSectionQuery('noticias'), 'noticia');
      expect(parseHermandadSectionQuery('cultos'), 'culto');
      expect(parseHermandadSectionQuery('actos'), 'acto');
      expect(parseHermandadSectionQuery('patrimonio'), 'patrimonio');
    });

    test('todas returns null', () {
      expect(parseHermandadSectionQuery('todas'), isNull);
      expect(parseHermandadSectionQuery('all'), isNull);
      expect(parseHermandadSectionQuery(''), isNull);
    });

    test('invalid returns null', () {
      expect(parseHermandadSectionQuery('foo'), isNull);
    });
  });

  group('hermandadSectionQueryValue', () {
    test('round trip', () {
      for (final category in ['noticia', 'culto', 'acto', 'patrimonio']) {
        final slug = hermandadSectionQueryValue(category);
        expect(parseHermandadSectionQuery(slug), category);
      }
    });
  });
}
