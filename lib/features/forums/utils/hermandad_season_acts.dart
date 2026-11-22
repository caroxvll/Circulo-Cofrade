import 'package:intl/intl.dart';

import '../../../shared/models/calendar_event.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import 'hermandad_season_profile.dart';

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

  String shortLabelFor(HermandadSeasonProfile profile) => switch (this) {
    HermandadSeasonActKind.muda => profile.mudaMode.shortLabel,
    _ => shortLabel,
  };

  /// Tipos de calendario que alimentan este hito.
  Set<EventType> eventTypesFor(HermandadSeasonProfile profile) => switch (this) {
    HermandadSeasonActKind.iguala => {EventType.iguala},
    HermandadSeasonActKind.ensayos => {EventType.ensayo},
    HermandadSeasonActKind.muda => switch (profile.mudaMode) {
        MudaRetranqueoMode.mudaOnly => {EventType.muda},
        _ => {EventType.muda, EventType.retranqueo},
      },
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

class SeasonPasoSlot {
  const SeasonPasoSlot({required this.label, required this.filled});

  final String label;
  final bool filled;
}

class HermandadSeasonActMilestone {
  const HermandadSeasonActMilestone({
    required this.kind,
    required this.status,
    required this.events,
    required this.filledSlots,
    required this.requiredSlots,
    this.detailLabel,
    this.pasoSlots = const [],
  });

  final HermandadSeasonActKind kind;
  final HermandadSeasonActStatus status;
  final List<CalendarEvent> events;
  final int filledSlots;
  final int requiredSlots;
  final String? detailLabel;
  /// Cristo / Virgen / Ambos según el perfil y lo publicado.
  final List<SeasonPasoSlot> pasoSlots;

  int get count => events.length;

  bool get isFilled => filledSlots >= requiredSlots && requiredSlots > 0;

  bool get hasAny => filledSlots > 0 || events.isNotEmpty;

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

  String get fractionLabel => '$filledSlots/$requiredSlots';

  String get statusLabel {
    if (status == HermandadSeasonActStatus.empty) {
      return requiredSlots > 1 ? '0/$requiredSlots' : 'Sin publicar';
    }
    final detail = detailLabel?.trim();
    if (detail != null && detail.isNotEmpty) return detail;
    return switch (status) {
      HermandadSeasonActStatus.upcoming => _upcomingLabel(),
      HermandadSeasonActStatus.done => _doneLabel(),
      HermandadSeasonActStatus.mixed => _mixedLabel(),
      HermandadSeasonActStatus.empty => 'Sin publicar',
    };
  }

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
    this.processionDay,
    this.hasAccount = true,
    this.profile = HermandadSeasonProfile.defaults,
  });

  final int year;
  final String hermandadName;
  final List<HermandadSeasonActMilestone> milestones;
  final String? topicId;
  final String? profileId;
  /// Día de estación del tablón (`Viernes Santo`, `Glorias`…).
  final String? processionDay;
  final HermandadSeasonProfile profile;

  /// False si el tablón existe pero no hay cuenta brotherhood vinculada.
  final bool hasAccount;

  int get filledCount =>
      milestones.where((m) => m.isFilled).length;

  int get totalCount => milestones.length;

  bool get isEmpty => milestones.every((m) => !m.hasAny);

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

String _foldSeasonQuery(String raw) {
  const from = 'áàäéèëíìïóòöúùüñÁÀÄÉÈËÍÌÏÓÒÖÚÙÜÑ';
  const to = 'aaaeeeiiiooouuunAAAEEEIIIOOOUUUN';
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().toLowerCase().trim();
}

/// Filtra cobertura por nombre y día de Semana Santa / Glorias.
List<HermandadSeasonActsSnapshot> filterSeasonActsCoverage({
  required List<HermandadSeasonActsSnapshot> rows,
  String query = '',
  String? processionDay,
}) {
  final q = _foldSeasonQuery(query);
  return [
    for (final row in rows)
      if ((processionDay == null || row.processionDay == processionDay) &&
          (q.isEmpty ||
              _foldSeasonQuery(row.hermandadName).contains(q) ||
              _foldSeasonQuery(row.processionDay ?? '').contains(q)))
        row,
  ];
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
  EventType.retranqueo,
  EventType.desarma,
};

const seasonActDbValues = <String>[
  'iguala',
  'ensayo',
  'muda',
  'retranqueo',
  'desarma',
];

String _foldOrganizer(String raw) {
  const from = 'áàäéèëíìïóòöúùüñÁÀÄÉÈËÍÌÏÓÒÖÚÙÜÑ';
  const to = 'aaaeeeiiiooouuunAAAEEEIIIOOOUUUN';
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().toLowerCase().trim();
}

String _canonicalOrganizer(String raw) {
  var value = _foldOrganizer(normalizeOrganizerKey(raw));
  const prefixes = [
    'real ',
    'ilustre ',
    'pontificia ',
    'hdad. ',
    'hdad ',
    'hermandad de la ',
    'hermandad de las ',
    'hermandad del ',
    'hermandad de ',
    'hermandad ',
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final prefix in prefixes) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length).trimLeft();
        changed = true;
      }
    }
  }
  return value;
}

bool organizerMatchesHermandadName(String organizer, String hermandadName) {
  final orgKey = normalizeOrganizerKey(organizer);
  final nameKey = normalizeOrganizerKey(hermandadName);
  if (nameKey.length < 2 || orgKey.length < 2) return false;
  if (orgKey == nameKey) return true;
  final orgCanon = _canonicalOrganizer(organizer);
  final nameCanon = _canonicalOrganizer(hermandadName);
  if (orgCanon.length < 3 || nameCanon.length < 3) return false;
  if (orgCanon == nameCanon) return true;
  final shorter = orgCanon.length <= nameCanon.length ? orgCanon : nameCanon;
  final longer = orgCanon.length > nameCanon.length ? orgCanon : nameCanon;
  return shorter.length >= 6 && longer.contains(shorter);
}

bool eventBelongsToHermandad(
  CalendarEvent event, {
  required String hermandadName,
  String? hermandadTopicId,
  String? profileId,
}) {
  final topicId = hermandadTopicId?.trim();
  final linked = event.hermandadTopicId?.trim();
  if (topicId != null &&
      topicId.isNotEmpty &&
      linked != null &&
      linked.isNotEmpty &&
      linked == topicId) {
    return true;
  }
  if (profileId != null &&
      profileId.isNotEmpty &&
      event.createdById == profileId) {
    return true;
  }
  final organizer = event.organizerLabel?.trim() ?? '';
  if (organizer.isEmpty) return false;
  return organizerMatchesHermandadName(organizer, hermandadName);
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

int _countCovering(List<CalendarEvent> events, SeasonPaso needed) {
  return events.where((e) => e.paso.covers(needed)).length;
}

int _ensayoFilled(List<CalendarEvent> events, int n) {
  if (events.isEmpty) return 0;
  final numbered = events
      .map((e) => e.seasonNumber)
      .whereType<int>()
      .toSet();
  if (numbered.isEmpty) return events.length.clamp(0, n);
  return numbered.length.clamp(0, n);
}

({int filled, int required, String? detail}) _slotsFor(
  HermandadSeasonActKind kind,
  List<CalendarEvent> events,
  HermandadSeasonProfile profile,
) {
  switch (kind) {
    case HermandadSeasonActKind.iguala:
      if (!profile.igualaSplit) {
        return (
          filled: events.isEmpty ? 0 : 1,
          required: 1,
          detail: null,
        );
      }
      final cristo = _countCovering(events, SeasonPaso.cristo) > 0;
      final virgen = _countCovering(events, SeasonPaso.virgen) > 0;
      return (
        filled: (cristo ? 1 : 0) + (virgen ? 1 : 0),
        required: 2,
        detail: cristo && virgen
            ? null
            : [
                if (cristo) 'Cristo',
                if (virgen) 'Virgen',
                if (!cristo) 'falta Cristo',
                if (!virgen) 'falta Virgen',
              ].join(' · '),
      );
    case HermandadSeasonActKind.ensayos:
      final n = profile.ensayoCount.clamp(1, 12);
      if (!profile.ensayoSplit) {
        final filled = _ensayoFilled(events, n);
        return (
          filled: filled,
          required: n,
          detail: n > 1 ? '$filled/$n ensayos' : null,
        );
      }
      final cristo = _ensayoFilled(
        events.where((e) => e.paso.covers(SeasonPaso.cristo)).toList(),
        n,
      );
      final virgen = _ensayoFilled(
        events.where((e) => e.paso.covers(SeasonPaso.virgen)).toList(),
        n,
      );
      return (
        filled: cristo + virgen,
        required: n * 2,
        detail: 'Cristo $cristo/$n · Virgen $virgen/$n',
      );
    case HermandadSeasonActKind.muda:
      final mudas = events.where((e) => e.type == EventType.muda).toList();
      final retrs =
          events.where((e) => e.type == EventType.retranqueo).toList();
      switch (profile.mudaMode) {
        case MudaRetranqueoMode.mudaOnly:
          return (
            filled: mudas.isEmpty ? 0 : 1,
            required: 1,
            detail: null,
          );
        case MudaRetranqueoMode.withRetranqueo:
          final combined = mudas.any((e) => e.withRetranqueo);
          final sameDay = mudas.any(
            (m) => retrs.any(
              (r) =>
                  m.date.year == r.date.year &&
                  m.date.month == r.date.month &&
                  m.date.day == r.date.day,
            ),
          );
          if (combined || sameDay) {
            return (filled: 1, required: 1, detail: 'Muda y retranqueo');
          }
          if (mudas.isNotEmpty) {
            return (filled: 0, required: 1, detail: 'Muda · falta retranqueo');
          }
          if (retrs.isNotEmpty) {
            return (filled: 0, required: 1, detail: 'Retranqueo · falta muda');
          }
          return (filled: 0, required: 1, detail: null);
        case MudaRetranqueoMode.split:
          final hasMuda = mudas.isNotEmpty;
          final hasRetr = retrs.isNotEmpty;
          return (
            filled: (hasMuda ? 1 : 0) + (hasRetr ? 1 : 0),
            required: 2,
            detail: hasMuda && hasRetr
                ? null
                : [
                    if (hasMuda) 'Muda',
                    if (hasRetr) 'Retranqueo',
                    if (!hasMuda) 'falta muda',
                    if (!hasRetr) 'falta retranqueo',
                  ].join(' · '),
          );
      }
    case HermandadSeasonActKind.desarma:
      return (
        filled: events.isEmpty ? 0 : 1,
        required: 1,
        detail: null,
      );
  }
}

List<SeasonPasoSlot> _pasoSlotsFor(
  HermandadSeasonActKind kind,
  List<CalendarEvent> events,
  HermandadSeasonProfile profile,
) {
  bool covers(SeasonPaso needed) =>
      events.any((e) => e.paso.covers(needed));

  if (kind == HermandadSeasonActKind.iguala) {
    if (profile.igualaSplit) {
      return [
        SeasonPasoSlot(label: 'Cristo', filled: covers(SeasonPaso.cristo)),
        SeasonPasoSlot(label: 'Virgen', filled: covers(SeasonPaso.virgen)),
      ];
    }
    if (events.isEmpty) return const [];
    final onlyAmbos = events.every((e) => e.paso == SeasonPaso.ambos);
    if (onlyAmbos ||
        (covers(SeasonPaso.cristo) && covers(SeasonPaso.virgen))) {
      return const [SeasonPasoSlot(label: 'Ambos', filled: true)];
    }
    if (covers(SeasonPaso.cristo)) {
      return const [SeasonPasoSlot(label: 'Cristo', filled: true)];
    }
    if (covers(SeasonPaso.virgen)) {
      return const [SeasonPasoSlot(label: 'Virgen', filled: true)];
    }
    return const [SeasonPasoSlot(label: 'Ambos', filled: true)];
  }

  if (kind == HermandadSeasonActKind.ensayos && profile.ensayoSplit) {
    final n = profile.ensayoCount.clamp(1, 12);
    return [
      SeasonPasoSlot(
        label: 'Cristo',
        filled: _ensayoFilled(
              events
                  .where((e) => e.paso.covers(SeasonPaso.cristo))
                  .toList(),
              n,
            ) >=
            n,
      ),
      SeasonPasoSlot(
        label: 'Virgen',
        filled: _ensayoFilled(
              events
                  .where((e) => e.paso.covers(SeasonPaso.virgen))
                  .toList(),
              n,
            ) >=
            n,
      ),
    ];
  }
  return const [];
}

List<HermandadSeasonActMilestone> buildSeasonActMilestones(
  List<CalendarEvent> events, {
  DateTime? now,
  HermandadSeasonProfile profile = HermandadSeasonProfile.defaults,
}) {
  final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));
  final milestones = <HermandadSeasonActMilestone>[];
  for (final kind in HermandadSeasonActKind.ordered) {
    final matched = sorted
        .where((e) => kind.eventTypesFor(profile).contains(e.type))
        .toList();
    final slots = _slotsFor(kind, matched, profile);
    var status = _statusFor(kind, matched, now: now);
    if (slots.filled > 0 && slots.filled < slots.required) {
      status = HermandadSeasonActStatus.mixed;
    }
    milestones.add(
      HermandadSeasonActMilestone(
        kind: kind,
        status: status,
        events: matched,
        filledSlots: slots.filled,
        requiredSlots: slots.required,
        detailLabel: slots.detail,
        pasoSlots: _pasoSlotsFor(kind, matched, profile),
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
  String? processionDay,
  bool hasAccount = true,
  DateTime? now,
  HermandadSeasonProfile profile = HermandadSeasonProfile.defaults,
}) {
  final own = allSeasonEvents
      .where(
        (e) => eventBelongsToHermandad(
          e,
          hermandadName: hermandadName,
          hermandadTopicId: topicId,
          profileId: profileId,
        ),
      )
      .toList();
  return HermandadSeasonActsSnapshot(
    year: year,
    hermandadName: hermandadName,
    topicId: topicId,
    profileId: profileId,
    processionDay: processionDay,
    hasAccount: hasAccount,
    profile: profile,
    milestones: buildSeasonActMilestones(own, now: now, profile: profile),
  );
}
