import 'package:cofradeo/features/forums/utils/hermandad_season_acts.dart';
import 'package:cofradeo/features/forums/utils/hermandad_season_profile.dart';
import 'package:cofradeo/shared/models/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event({
  required EventType type,
  required SeasonPaso paso,
  String organizer = 'Hermandad de la Estrella',
}) {
  return CalendarEvent(
    date: DateTime(2027, 2, 6),
    title: 'Acto',
    subtitle: '',
    type: type,
    organizerLabel: organizer,
    paso: paso,
  );
}

void main() {
  test('Ambos cubre Cristo y Virgen, no el segundo Cristo', () {
    expect(SeasonPaso.ambos.covers(SeasonPaso.cristo), isTrue);
    expect(SeasonPaso.ambos.covers(SeasonPaso.virgen), isTrue);
    expect(SeasonPaso.ambos.covers(SeasonPaso.cristo2), isFalse);
    expect(SeasonPaso.cristo2.covers(SeasonPaso.cristo), isFalse);
  });

  test('Hermandad de un paso solo marca ese círculo', () {
    final snapshot = buildHermandadSeasonActsSnapshot(
      year: 2027,
      hermandadName: 'Estrella',
      allSeasonEvents: [
        _event(type: EventType.iguala, paso: SeasonPaso.virgen),
      ],
      profile: const HermandadSeasonProfile(
        pasosLayout: HermandadPasosLayout.virgen,
      ),
    );
    final iguala = snapshot.milestone(HermandadSeasonActKind.iguala)!;
    expect(iguala.pasoSlots.map((s) => s.label), ['Virgen']);
    expect(iguala.pasoSlots.single.filled, isTrue);
    expect(iguala.requiredSlots, 1);
    expect(iguala.isFilled, isTrue);
  });

  test('Tres pasos: Cristo 1, Cristo 2 y Virgen independientes', () {
    final snapshot = buildHermandadSeasonActsSnapshot(
      year: 2027,
      hermandadName: 'Estrella',
      allSeasonEvents: [
        _event(type: EventType.iguala, paso: SeasonPaso.cristo),
        _event(type: EventType.iguala, paso: SeasonPaso.virgen),
      ],
      profile: const HermandadSeasonProfile(
        pasosLayout: HermandadPasosLayout.dosCristosVirgen,
      ),
    );
    final iguala = snapshot.milestone(HermandadSeasonActKind.iguala)!;
    expect(iguala.pasoSlots.map((s) => s.label).toList(), [
      'Cristo 1',
      'Cristo 2',
      'Virgen',
    ]);
    expect(iguala.pasoSlots.map((s) => s.filled).toList(), [true, false, true]);
    expect(iguala.requiredSlots, 3);
    expect(iguala.filledSlots, 2);
    expect(iguala.isFilled, isFalse);
  });

  test('Pasión no es la misma hermandad que Pasión y Muerte', () {
    expect(
      organizerMatchScore('Pasión', 'Pasión y Muerte'),
      0,
    );
    expect(
      organizerMatchScore(
        'Hermandad de Pasión',
        'Hermandad de Pasión y Muerte',
      ),
      0,
    );
    expect(
      organizerMatchScore('Hermandad de Pasión', 'Pasión'),
      greaterThanOrEqualTo(90),
    );
    expect(
      organizerMatchScore('Jesús del Gran Poder', 'Gran Poder'),
      greaterThan(0),
    );
  });

  test('Otras hermandades de nombre parecido no se cruzan', () {
    expect(
      organizerMatchScore(
        'Soledad de San Buenaventura',
        'La Soledad de San Lorenzo',
      ),
      0,
    );
    expect(
      organizerMatchScore('Soledad', 'Soledad de San Lorenzo'),
      0,
    );
    expect(
      organizerMatchScore('Soledad', 'Soledad de San Buenaventura'),
      0,
    );
    expect(
      organizerMatchScore('Esperanza', 'La Esperanza de Triana'),
      0,
    );
    expect(
      organizerMatchScore('Esperanza', 'Bendición y Esperanza'),
      0,
    );
    expect(
      organizerMatchScore('Santa Cruz', 'Vera Cruz'),
      0,
    );
  });

  test('Al crear evento, un solo paso no pide elegir', () {
    expect(HermandadPasosLayout.cristo.eventChoices, [SeasonPaso.cristo]);
    expect(
      HermandadPasosLayout.dosCristosVirgen.eventChoices,
      [SeasonPaso.cristo, SeasonPaso.cristo2, SeasonPaso.virgen],
    );
    expect(
      HermandadPasosLayout.virgen.resolvedEventPaso(SeasonPaso.ambos),
      SeasonPaso.virgen,
    );
  });
}
