import 'package:cofradeo/features/forums/widgets/hermandad_follow_sections_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeHermandadNotifyCategories', () {
    test('null significa todas; vacío significa ninguna', () {
      expect(normalizeHermandadNotifyCategories(null), isNull);
      expect(normalizeHermandadNotifyCategories([]), isEmpty);
    });

    test('las cuatro secciones se normalizan a null', () {
      expect(
        normalizeHermandadNotifyCategories([
          'noticia',
          'culto',
          'acto',
          'patrimonio',
        ]),
        isNull,
      );
    });

    test('subconjunto conserva orden canónico', () {
      expect(
        normalizeHermandadNotifyCategories(['acto', 'noticia']),
        ['noticia', 'acto'],
      );
    });
  });

  group('hermandadNotifyCategoriesLabel', () {
    test('etiquetas legibles', () {
      expect(hermandadNotifyCategoriesLabel(null), 'Todas las secciones');
      expect(hermandadNotifyCategoriesLabel([]), 'Sin avisos');
      expect(
        hermandadNotifyCategoriesLabel(['culto', 'patrimonio']),
        'Cultos, Patrimonio',
      );
    });
  });
}
