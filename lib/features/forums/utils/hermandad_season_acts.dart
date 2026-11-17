import 'package:intl/intl.dart';

import '../../../shared/models/calendar_event.dart';
import '../../calendar/utils/calendar_event_utils.dart';

/// Hitos de temporada que interesa seguir por hermandad.
enum HermandadSeasonActKind {
  iguala,
  ensayos,
  muda,
  desarma;

  String get label => switch (this) {
    HermandadSeasonActKind.iguala => 'Igualá',
    HermandadSeasonActKind.ensayos => 'Ensayos',
    HermandadSeasonActKind.muda => 'Muda',
    HermandadSeasonActKind.desarma => 'Desarmá',
  };

  String get shortLabel => switch (this) {
    HermandadSeasonActKind.iguala => 'Igualá',
    HermandadSeasonActKind.ensayos => 'Ensayos',
    HermandadSeasonActKind.muda => 'Muda',
    HermandadSeasonActKind.desarma => 'Desarmá',
  };

  /// Tipos de calendario que alimentan este hito.
  Set<EventType> get eventTypes => switch (this) {
    HermandadSeasonActKind.iguala => {EventType.iguala},
    HermandadSeasonActKind.ensayos => {EventType.ensayo},
    HermandadSeasonActKind.muda => {EventType.muda},
    HermandadSeasonActKind.desarma => {EventType.desarma},
  };

  static const ordered = HermandadSeasonActKind.values;
}

enum HermandadSeasonActStatus {
  /// Sin eventos publicados.
  empty,

  /// Hay fecha(s) y aún no ha llegado la próxima / la única.
  upcoming,

  /// Ya pasó (o, en ensayos, todos pasaron).
  done,

  /// Ensayos: algunos hechos y otros por venir.
  mixed,
}

class HermandadSeasonActMilestone {
  const HermandadSeasonActMilestone({
    required this.kind,
    required this.status,
    required this.events,
  });

  final HermandadSeasonActKind kind;
  final HermandadSeasonActStatus status;
  final List<CalendarEvent> events;

  int get count => events.length;

  bool get isFilled => status != HermandadSeasonActStatus.empty;

  DateTime? get nextDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final event in events) {
      if (!event.date.isBefore(today)) return event.date;
    }
    return null;
  }

  DateTime? get lastDate {
    if (events.isEmpty) return null;
    return events.last.date;
  }

  String get statusLabel => switch (status) {
    HermandadSeasonActStatus.empty => 'Sin publicar',
    HermandadSeasonActStatus.upcoming => _upcomingLabel(),
    HermandadSeasonActStatus.done => _doneLabel(),
    HermandadSeasonActStatus.mixed => _mixedLabel(),
  };

  String _formatDay(DateTime date) =>
      DateFormat('d MMM', 'es').format(date).replaceAll('.', '');

  String _upcomingLabel() {
    final next = nextDate;
    if (next == null) return 'Programado';
    if (kind == HermandadSeasonActKind.ensayos && count > 1) {
      return '$count · próximo ${_formatDay(next)}';
    }
    return _formatDay(next);
  }

  String _doneLabel() {
    final last = lastDate;
    if (last == null) return 'Hecho';
    if (kind == HermandadSeasonActKind.ensayos && count > 1) {
      return '$count hechos';
    }
    return 'Hecho · ${_formatDay(last)}';
  }

  String _mixedLabel() {
    final next = nextDate;
    final done = events
        .where((e) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          return e.date.isBefore(today);
        })
        .length;
    if (next == null) return '$done hechos';
    return '$done hechos · próximo ${_formatDay(next)}';
  }
}

class HermandadSeasonActsSnapshot {
  const HermandadSeasonActsSnapshot({
    required this.year,
    required this.hermandadName,
    required this.milestones,
    this.topicId,
    this.profileId,
    this.hasAccount = true,
  });

  final int year;
  final String hermandadName;
  final List<HermandadSeasonActMilestone> milestones;
  final String? topicId;
  final String? profileId;

  /// False si el tablón existe pero no hay cuenta brotherhood vinculada.
  final bool hasAccount;

  int get filledCount =>
      milestones.where((m) => m.isFilled).length;

  int get totalCount => milestones.length;

  bool get isEmpty => filledCount == 0;

  bool get isComplete => filledCount == totalCount;

  HermandadSeasonActMilestone? milestone(HermandadSeasonActKind kind) {
    for (final item in milestones) {
      if (item.kind == kind) return item;
    }
    return null;
  }

  String get coverageLabel {
    if (!hasAccount) return 'Sin cuenta';
    if (isEmpty) return 'Sin actos';
    if (isComplete) return 'Completo';
    return '$filledCount/$totalCount';
  }
}

class HermandadSeasonActsCoverage {
  const HermandadSeasonActsCoverage({
    required this.year,
    required this.rows,
  });

  final int year;
  final List<HermandadSeasonActsSnapshot> rows;

  List<HermandadSeasonActsSnapshot> get missingAccount =>
      rows.where((r) => !r.hasAccount).toList();

  List<HermandadSeasonActsSnapshot> get emptyActs =>
      rows.where((r) => r.hasAccount && r.isEmpty).toList();

  List<HermandadSeasonActsSnapshot> get partial =>
      rows.where((r) => r.hasAccount && !r.isEmpty && !r.isComplete).toList();

  List<HermandadSeasonActsSnapshot> get complete =>
      rows.where((r) => r.hasAccount && r.isComplete).toList();
}

/// Año civil de la temporada (p. ej. 2026).
int currentSeasonActsYear([DateTime? now]) => (now ?? DateTime.now()).year;

({DateTime start, DateTime end}) seasonActsRange(int year) {
  return (
    start: DateTime(year, 1, 1),
    end: DateTime(year + 1, 1, 1),
  );
}

const seasonActEventTypes = <EventType>{
  EventType.iguala,
  EventType.ensayo,
  EventType.muda,
  EventType.desarma,
};

const seasonActDbValues = <String>[
  'iguala',
  'ensayo',
  'muda',
  'desarma',
];

bool eventBelongsToHermandad(
  CalendarEvent event, {
  required String hermandadName,
  String? profileId,
}) {
  if (profileId != null &&
      profileId.isNotEmpty &&
      event.createdById == profileId) {
    return true;
  }
  final organizer = event.organizerLabel?.trim() ?? '';
  if (organizer.isEmpty) return false;
  final orgKey = normalizeOrganizerKey(organizer);
  final nameKey = normalizeOrganizerKey(hermandadName);
  if (nameKey.length < 2 || orgKey.length < 2) return false;
  return orgKey == nameKey;
}

HermandadSeasonActStatus _statusFor(
  HermandadSeasonActKind kind,
  List<CalendarEvent> events, {
  DateTime? now,
}) {
  if (events.isEmpty) return HermandadSeasonActStatus.empty;
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final upcoming = events.where((e) => !e.date.isBefore(today)).length;
  final done = events.length - upcoming;

  if (kind == HermandadSeasonActKind.ensayos) {
    if (done > 0 && upcoming > 0) return HermandadSeasonActStatus.mixed;
    if (upcoming > 0) return HermandadSeasonActStatus.upcoming;
    return HermandadSeasonActStatus.done;
  }

  if (upcoming > 0) return HermandadSeasonActStatus.upcoming;
  return HermandadSeasonActStatus.done;
}

List<HermandadSeasonActMilestone> buildSeasonActMilestones(
  List<CalendarEvent> events, {
  DateTime? now,
}) {
  final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));
  final milestones = <HermandadSeasonActMilestone>[];
  for (final kind in HermandadSeasonActKind.ordered) {
    final matched =
        sorted.where((e) => kind.eventTypes.contains(e.type)).toList();
    milestones.add(
      HermandadSeasonActMilestone(
        kind: kind,
        status: _statusFor(kind, matched, now: now),
        events: matched,
      ),
    );
  }
  return milestones;
}

HermandadSeasonActsSnapshot buildHermandadSeasonActsSnapshot({
  required int year,
  required String hermandadName,
  required List<CalendarEvent> allSeasonEvents,
  String? topicId,
  String? profileId,
  bool hasAccount = true,
  DateTime? now,
}) {
  final own = allSeasonEvents
      .where(
        (e) => eventBelongsToHermandad(
          e,
          hermandadName: hermandadName,
          profileId: profileId,
        ),
      )
      .toList();
  return HermandadSeasonActsSnapshot(
    year: year,
    hermandadName: hermandadName,
    topicId: topicId,
    profileId: profileId,
    hasAccount: hasAccount,
    milestones: buildSeasonActMilestones(own, now: now),
  );
}
