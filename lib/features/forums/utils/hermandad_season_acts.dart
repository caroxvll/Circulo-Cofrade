import 'package:intl/intl.dart';

import '../../../shared/models/calendar_event.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import '../../calendar/utils/holy_week_countdown.dart';
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
  const SeasonPasoSlot({
    required this.label,
    required this.filled,
    this.hint,
  });

  final String label;
  final bool filled;
  final String? hint;

  String get shortLabel => switch (label) {
        'Cristo' => 'C',
        'Cristo 1' => 'C1',
        'Cristo 2' => 'C2',
        'Virgen' => 'V',
        'Ambos' => '2',
        _ => label,
      };
}

SeasonPaso? seasonPasoFromSlotLabel(String label) => switch (label) {
      'Cristo' || 'Cristo 1' => SeasonPaso.cristo,
      'Cristo 2' => SeasonPaso.cristo2,
      'Virgen' => SeasonPaso.virgen,
      _ => null,
    };

List<CalendarEvent> eventsForPasoSlot(
  HermandadSeasonActMilestone milestone,
  SeasonPasoSlot slot,
) {
  final needed = seasonPasoFromSlotLabel(slot.label);
  if (needed == null) return milestone.events;
  return [
    for (final event in milestone.events)
      if (event.paso.covers(needed)) event,
  ];
}

enum SeasonActPasoFilter {
  igualaCristo,
  igualaCristo2,
  igualaVirgen,
  igualaAmbas,
  ensayoCristo,
  ensayoCristo2,
  ensayoVirgen;

  String get label => switch (this) {
        SeasonActPasoFilter.igualaCristo => 'Igualá Cristo',
        SeasonActPasoFilter.igualaCristo2 => 'Igualá Cristo 2',
        SeasonActPasoFilter.igualaVirgen => 'Igualá Virgen',
        SeasonActPasoFilter.igualaAmbas => 'Igualá ambas',
        SeasonActPasoFilter.ensayoCristo => 'Ensayos Cristo',
        SeasonActPasoFilter.ensayoCristo2 => 'Ensayos Cristo 2',
        SeasonActPasoFilter.ensayoVirgen => 'Ensayos Virgen',
      };
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

  bool hasPasoFilled(HermandadSeasonActKind kind, String pasoLabel) {
    final item = milestone(kind);
    if (item == null) return false;
    for (final slot in item.pasoSlots) {
      if (!slot.filled) continue;
      if (slot.label == pasoLabel) return true;
      if (pasoLabel == 'Cristo' && slot.label == 'Cristo 1') return true;
    }
    return false;
  }

  bool matchesPasoFilter(SeasonActPasoFilter filter) {
    return switch (filter) {
      SeasonActPasoFilter.igualaCristo =>
        hasPasoFilled(HermandadSeasonActKind.iguala, 'Cristo'),
      SeasonActPasoFilter.igualaCristo2 =>
        hasPasoFilled(HermandadSeasonActKind.iguala, 'Cristo 2'),
      SeasonActPasoFilter.igualaVirgen =>
        hasPasoFilled(HermandadSeasonActKind.iguala, 'Virgen'),
      SeasonActPasoFilter.igualaAmbas =>
        hasPasoFilled(HermandadSeasonActKind.iguala, 'Cristo') &&
            hasPasoFilled(HermandadSeasonActKind.iguala, 'Virgen'),
      SeasonActPasoFilter.ensayoCristo =>
        hasPasoFilled(HermandadSeasonActKind.ensayos, 'Cristo'),
      SeasonActPasoFilter.ensayoCristo2 =>
        hasPasoFilled(HermandadSeasonActKind.ensayos, 'Cristo 2'),
      SeasonActPasoFilter.ensayoVirgen =>
        hasPasoFilled(HermandadSeasonActKind.ensayos, 'Virgen'),
    };
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
  SeasonActPasoFilter? pasoFilter,
}) {
  final q = _foldSeasonQuery(query);
  return [
    for (final row in rows)
      if ((processionDay == null || row.processionDay == processionDay) &&
          (pasoFilter == null || row.matchesPasoFilter(pasoFilter)) &&
          (q.isEmpty ||
              _foldSeasonQuery(row.hermandadName).contains(q) ||
              _foldSeasonQuery(row.processionDay ?? '').contains(q)))
        row,
  ];
}

/// Año de Semana Santa de la temporada (p. ej. noviembre 2026 → 2027).
int currentSeasonActsYear([DateTime? now]) => liturgicalSeasonYear(now);

/// De septiembre del año anterior a septiembre del año de Ramos, para
/// recoger igualás de otoño y mudas/desarmás de primavera-verano.
({DateTime start, DateTime end}) seasonActsRange(int year) {
  return (
    start: DateTime(year - 1, 9, 1),
    end: DateTime(year, 9, 1),
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
    'venerable ',
    'sacramental ',
    'hdad. ',
    'hdad ',
    'hermandad de la ',
    'hermandad de las ',
    'hermandad del ',
    'hermandad de los ',
    'hermandad de ',
    'hermandad ',
    'de la ',
    'de las ',
    'de los ',
    'del ',
    'de ',
    'la ',
    'el ',
    'las ',
    'los ',
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

int organizerMatchScore(String organizer, String hermandadName) {
  final orgKey = normalizeOrganizerKey(organizer);
  final nameKey = normalizeOrganizerKey(hermandadName);
  if (nameKey.length < 2 || orgKey.length < 2) return 0;
  if (orgKey == nameKey) return 100;
  final orgCanon = _canonicalOrganizer(organizer);
  final nameCanon = _canonicalOrganizer(hermandadName);
  if (orgCanon.length < 3 || nameCanon.length < 3) return 0;
  if (orgCanon == nameCanon) return 90;
  final shorter = orgCanon.length <= nameCanon.length ? orgCanon : nameCanon;
  final longer = orgCanon.length > nameCanon.length ? orgCanon : nameCanon;
  if (shorter.length >= 6 && longer.contains(shorter)) {
    return 40 + (shorter.length * 2).clamp(0, 40);
  }
  return 0;
}

bool organizerMatchesHermandadName(String organizer, String hermandadName) {
  return organizerMatchScore(organizer, hermandadName) > 0;
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
      if (!profile.pasosLayout.splitsIguala(profile.igualaSplit)) {
        final tracked = profile.pasosLayout.trackedPasos;
        final hits = events.where(
          (e) => tracked.any((paso) => e.paso.covers(paso)),
        );
        return (
          filled: hits.isEmpty ? 0 : 1,
          required: 1,
          detail: null,
        );
      }
      final tracked = profile.pasosLayout.trackedPasos;
      var filled = 0;
      final missing = <String>[];
      for (final paso in tracked) {
        if (_countCovering(events, paso) > 0) {
          filled++;
        } else {
          missing.add(profile.pasosLayout.slotLabel(paso));
        }
      }
      return (
        filled: filled,
        required: tracked.length,
        detail: missing.isEmpty
            ? null
            : missing.map((name) => 'falta $name').join(' · '),
      );
    case HermandadSeasonActKind.ensayos:
      final n = profile.ensayoCount.clamp(1, 12);
      if (!profile.pasosLayout.splitsEnsayo(profile.ensayoSplit)) {
        final tracked = profile.pasosLayout.trackedPasos;
        final ofPaso = events
            .where((e) => tracked.any((paso) => e.paso.covers(paso)))
            .toList();
        final filled = _ensayoFilled(ofPaso, n);
        return (
          filled: filled,
          required: n,
          detail: n > 1 ? '$filled/$n ensayos' : null,
        );
      }
      final tracked = profile.pasosLayout.trackedPasos;
      var filled = 0;
      final bits = <String>[];
      for (final paso in tracked) {
        final count = _ensayoFilled(
          events.where((e) => e.paso.covers(paso)).toList(),
          n,
        );
        filled += count;
        bits.add('${profile.pasosLayout.slotLabel(paso)} $count/$n');
      }
      return (
        filled: filled,
        required: n * tracked.length,
        detail: bits.join(' · '),
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
  final tracked = profile.pasosLayout.trackedPasos;
  if (tracked.isEmpty) return const [];

  if (kind == HermandadSeasonActKind.iguala) {
    return [
      for (final paso in tracked)
        SeasonPasoSlot(
          label: profile.pasosLayout.slotLabel(paso),
          filled: events.any((e) => e.paso.covers(paso)),
        ),
    ];
  }

  if (kind == HermandadSeasonActKind.ensayos) {
    final n = profile.ensayoCount.clamp(1, 12);
    final showHint =
        profile.pasosLayout.splitsEnsayo(profile.ensayoSplit) || n > 1;
    final slots = <SeasonPasoSlot>[];
    for (final paso in tracked) {
      final count = _ensayoFilled(
        events.where((e) => e.paso.covers(paso)).toList(),
        n,
      );
      slots.add(
        SeasonPasoSlot(
          label: profile.pasosLayout.slotLabel(paso),
          filled: count > 0,
          hint: showHint ? '$count/$n' : null,
        ),
      );
    }
    return slots;
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
