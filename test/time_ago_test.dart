import 'package:cofradeo/core/utils/time_ago.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 23, 17, 24);

  test('en el directo enseña la hora de reloj', () {
    expect(
      formatLiveStamp(DateTime(2026, 11, 23, 17, 8), now: now),
      '17:08',
    );
  });

  test('si es de ayer, lo dice con la hora', () {
    expect(
      formatLiveStamp(DateTime(2026, 11, 22, 19, 10), now: now),
      'ayer 19:10',
    );
  });

  test('si es de otro día, pone fecha y hora', () {
    expect(
      formatLiveStamp(DateTime(2026, 11, 20, 9, 5), now: now),
      '20 nov · 09:05',
    );
  });
}
