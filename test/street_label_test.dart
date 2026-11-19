import 'package:cofradeo/core/utils/street_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('junta la calle y el número', () {
    expect(
      formatStreetLabel(
        thoroughfare: 'Calle San Jacinto',
        subThoroughfare: '12',
        locality: 'Sevilla',
      ),
      'Calle San Jacinto, 12',
    );
  });

  test('no repite el número si ya va en la vía', () {
    expect(
      formatStreetLabel(
        thoroughfare: 'Calle Betis 48',
        subThoroughfare: '48',
      ),
      'Calle Betis 48',
    );
  });

  test('recorta ciudad, código postal y país', () {
    expect(
      formatStreetLabel(
        street: 'Calle San Jacinto, 12, 41010, Sevilla, España',
        locality: 'Sevilla',
      ),
      'Calle San Jacinto, 12',
    );
  });

  test('ignora plus codes y vías sin nombre', () {
    expect(
      formatStreetLabel(
        thoroughfare: 'Unnamed Road',
        name: '8FXX+2C Sevilla',
        street: 'Calle Pureza, Triana, Sevilla',
        subLocality: 'Triana',
        locality: 'Sevilla',
      ),
      'Calle Pureza',
    );
  });

  test('Mi ubicación no cuenta como calle', () {
    expect(isGenericPlaceLabel('Mi ubicación'), isTrue);
    expect(isGenericPlaceLabel('Calle San Jacinto, 12'), isFalse);
  });
}
