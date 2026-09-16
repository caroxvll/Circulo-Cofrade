import 'package:flutter_test/flutter_test.dart';

import 'package:cofradeo/features/forums/utils/hermandad_board_display.dart';

void main() {
  test('detects template body', () {
    const template =
        'Este es el espacio de seguimiento de La Borriquita...\n\n'
        'Cuando exista una cuenta verificada de la hermandad, sus publicaciones '
        'aparecerán identificadas como información oficial.';
    expect(isHermandadBoardTemplateBody(template), isTrue);
    expect(hermandadBoardCustomBody(template), isNull);
  });

  test('parses hermandad title', () {
    final parsed = parseHermandadTopicTitle('Domingo de Ramos · La Borriquita');
    expect(parsed.processionDay, 'Domingo de Ramos');
    expect(parsed.hermandadName, 'La Borriquita');
  });
}
