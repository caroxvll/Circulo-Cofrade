import 'package:cofradeo/core/router/safe_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta rutas internas de tema y noticia', () {
    expect(
      safeInternalLocation('/noticias/tema/abc?reply=1'),
      '/noticias/tema/abc?reply=1',
    );
    expect(
      safeInternalLocation('/foros/foro-1/tema/tema-2'),
      '/foros/foro-1/tema/tema-2',
    );
  });

  test('rechaza destinos fuera de la app', () {
    expect(safeInternalLocation('https://evil.test/noticias'), isNull);
    expect(safeInternalLocation('//evil.test'), isNull);
    expect(safeInternalLocation('noticias'), isNull);
    expect(safeInternalLocation(null), isNull);
  });
}
