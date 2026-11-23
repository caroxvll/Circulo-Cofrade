import 'package:cofradeo/core/network/app_network_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un solo aviso, en el tono de la app', () {
    const offline = AppNetworkStatus(kind: AppNetworkKind.offline);
    const saturated = AppNetworkStatus(kind: AppNetworkKind.degraded);
    expect(
      offline.bannerMessage,
      'Sin conexión · se muestra lo último que se pudo cargar',
    );
    expect(saturated.bannerMessage, offline.bannerMessage);
    expect(offline.showBanner, isTrue);
    expect(const AppNetworkStatus().showBanner, isFalse);
  });
}
