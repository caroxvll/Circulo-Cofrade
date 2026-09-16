import 'package:flutter_test/flutter_test.dart';

import 'package:cofradeo/core/utils/forum_text_format.dart';

void main() {
  test('bold title + body', () {
    const raw = '**Cartel de la Semana Santa 26**\n\nEstá inspirado por el cristo de las M...';
    final excerpt = plainTextForExcerpt(raw, maxLength: 80);
    expect(excerpt, isNot(contains('\$1')));
    expect(excerpt, isNot(contains('**')));
    expect(excerpt, contains('Cartel de la Semana Santa 26'));
    expect(excerpt, contains('Está inspirado'));
  });

  test('code block then body', () {
    const raw = '```\n**Cartel**\n```\n\nEstá inspirado por el cristo';
    final excerpt = plainTextForExcerpt(raw, maxLength: 80);
    expect(excerpt, isNot(contains('\$1')));
    expect(excerpt, contains('Está inspirado'));
  });

  test('image markdown line then body', () {
    const raw = '![Cartel](https://example.com/img.jpg)\n\nEstá inspirado';
    final excerpt = plainTextForExcerpt(raw, maxLength: 80);
    expect(excerpt, isNot(contains('\$1')));
    expect(excerpt, contains('Está inspirado'));
  });

  test('bold title image and body', () {
    const raw =
        '**Cartel de la Semana Santa 26**\n\n![img](https://x.com/a.jpg)\n\nEstá inspirado por el cristo';
    final excerpt = plainTextForExcerpt(raw, maxLength: 120);
    // ignore: avoid_print
    print('excerpt: [$excerpt]');
    expect(excerpt, isNot(contains('\$1')));
    expect(excerpt, contains('Está inspirado'));
  });
}
