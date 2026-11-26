import 'package:cofradeo/features/calendar/utils/calendar_event_utils.dart';
import 'package:cofradeo/shared/models/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

CalendarEvent _besamanos({DateTime? spanUntil}) {
  return CalendarEvent(
    id: 'b1',
    date: DateTime(2026, 3, 12),
    title: 'Besamanos de la Virgen',
    subtitle: '',
    type: EventType.besamanos,
    time: '18:00',
    spanUntil: spanUntil,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  test('un besamanos de varios días ocupa cada jornada del tramo', () {
    final event = _besamanos(spanUntil: DateTime(2026, 3, 15));

    expect(eventCoversDay(event, DateTime(2026, 3, 12)), isTrue);
    expect(eventCoversDay(event, DateTime(2026, 3, 14)), isTrue);
    expect(eventCoversDay(event, DateTime(2026, 3, 15)), isTrue);
    expect(eventCoversDay(event, DateTime(2026, 3, 16)), isFalse);
    expect(eventSpanEdgeOn(event, DateTime(2026, 3, 12)), EventSpanEdge.start);
    expect(eventSpanEdgeOn(event, DateTime(2026, 3, 13)), EventSpanEdge.middle);
    expect(eventSpanEdgeOn(event, DateTime(2026, 3, 15)), EventSpanEdge.end);
    expect(formatEventWhenLabel(event), 'Del 12 al 15 de marzo');

    final visible = eventsOnDate([event], DateTime(2026, 3, 14));
    expect(visible, hasLength(1));
  });

  test('sin último día, el besamanos sigue en una sola fecha', () {
    final event = _besamanos();
    expect(eventSpanEndDay(event), isNull);
    expect(eventCoversDay(event, DateTime(2026, 3, 13)), isFalse);
    expect(
      eventOverlapsRange(
        event,
        DateTime(2026, 4, 1),
        DateTime(2026, 5, 1),
      ),
      isFalse,
    );
  });

  test('un tramo que empieza en febrero se ve en marzo', () {
    final event = CalendarEvent(
      date: DateTime(2026, 2, 27),
      title: 'Besapiés',
      subtitle: '',
      type: EventType.besapies,
      spanUntil: DateTime(2026, 3, 2),
    );
    expect(
      eventOverlapsRange(
        event,
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      ),
      isTrue,
    );
    expect(eventsForMonth([event], DateTime(2026, 3)), hasLength(1));
  });
}
