import 'package:cofradeo/core/utils/text_normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quita escapes Markdown visibles de Quill (Cas\\.)', () {
    expect(
      normalizeStoredText(
        r'obra de Antoine Cas\. ¿Qué opinais?',
      ),
      'obra de Antoine Cas. ¿Qué opinais?',
    );
  });

  test('convierte \\n literales y limpia puntuación', () {
    expect(
      normalizeStoredText(r'Hola\nCas\.'),
      'Hola\nCas.',
    );
  });
}
