/// Tipos de actividad en el calendario cofrade.

enum EventType {
  procesion('Procesiones'),

  gloria('Glorias'),

  ensayo('Ensayos'),

  iguala('Igualás'),

  concierto('Conciertos'),

  evento('Eventos');

  const EventType(this.label);

  final String label;

  static EventType fromDb(String? raw) {
    return switch (raw) {
      'procesion' => EventType.procesion,

      'gloria' => EventType.gloria,

      'ensayo' => EventType.ensayo,

      'iguala' => EventType.iguala,

      'concierto' => EventType.concierto,

      _ => EventType.evento,
    };
  }

  String get dbValue => switch (this) {
    EventType.procesion => 'procesion',

    EventType.gloria => 'gloria',

    EventType.ensayo => 'ensayo',

    EventType.iguala => 'iguala',

    EventType.concierto => 'concierto',

    EventType.evento => 'evento',
  };

  /// Etiqueta corta para la celda del calendario.
  String get cellLabel => switch (this) {
    EventType.procesion => 'Procesión',
    EventType.gloria => 'Gloria',
    EventType.ensayo => 'Ensayo',
    EventType.iguala => 'Iguala',
    EventType.concierto => 'Concierto',
    EventType.evento => 'Evento',
  };
}

enum CalendarEventStatus { published, pendingReview, rejected }

extension CalendarEventStatusX on CalendarEventStatus {
  static CalendarEventStatus fromDb(String? raw) => switch (raw) {
    'pending_review' => CalendarEventStatus.pendingReview,
    'rejected' => CalendarEventStatus.rejected,
    _ => CalendarEventStatus.published,
  };

  String get dbValue => switch (this) {
    CalendarEventStatus.published => 'published',
    CalendarEventStatus.pendingReview => 'pending_review',
    CalendarEventStatus.rejected => 'rejected',
  };

  bool get isVisibleInCalendar => this == CalendarEventStatus.published;
}

class CalendarEvent {
  const CalendarEvent({
    this.id,

    required this.date,

    required this.title,

    required this.subtitle,

    required this.type,

    this.dayLabel,

    this.time,

    this.location,

    this.organizerLabel,

    this.createdById,

    this.publisherHandle,

    this.customIconUrl,

    this.coverImageUrl,
    this.status = CalendarEventStatus.published,
  });

  final String? id;

  final DateTime date;

  final String title;

  final String subtitle;

  final EventType type;

  final String? dayLabel;

  final String? time;

  final String? location;

  final String? organizerLabel;

  final String? createdById;

  final String? publisherHandle;

  final String? customIconUrl;

  /// Foto de portada para carrusel y miniatura en listas.
  final String? coverImageUrl;

  final CalendarEventStatus status;

  bool get isPublished => status == CalendarEventStatus.published;
  bool get isPendingReview => status == CalendarEventStatus.pendingReview;

  /// Etiqueta corta bajo el día en el grid (p. ej. «Iguala», «Procesión»).
  String get calendarCellLabel {
    if (dayLabel != null && dayLabel!.trim().isNotEmpty) {
      return dayLabel!.replaceAll('\n', ' ').trim();
    }
    return type.cellLabel;
  }

  CalendarEvent copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? subtitle,
    EventType? type,
    String? dayLabel,
    String? time,
    String? location,
    String? organizerLabel,
    String? createdById,
    String? publisherHandle,
    String? customIconUrl,
    String? coverImageUrl,
    CalendarEventStatus? status,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      dayLabel: dayLabel ?? this.dayLabel,
      time: time ?? this.time,
      location: location ?? this.location,
      organizerLabel: organizerLabel ?? this.organizerLabel,
      createdById: createdById ?? this.createdById,
      publisherHandle: publisherHandle ?? this.publisherHandle,
      customIconUrl: customIconUrl ?? this.customIconUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      status: status ?? this.status,
    );
  }
}

/// Filtros del calendario (chip «Todas» + una por tipo).

enum EventFilter {
  todas('Todas'),

  conciertos('Conciertos'),

  igualas('Igualás'),

  ensayos('Ensayos'),

  procesiones('Procesiones'),

  glorias('Glorias'),

  eventos('Eventos'),

  guardados('Guardados');

  const EventFilter(this.label);

  final String label;

  EventType? get type => switch (this) {
    EventFilter.todas => null,
    EventFilter.guardados => null,

    EventFilter.conciertos => EventType.concierto,

    EventFilter.igualas => EventType.iguala,

    EventFilter.ensayos => EventType.ensayo,

    EventFilter.procesiones => EventType.procesion,

    EventFilter.glorias => EventType.gloria,

    EventFilter.eventos => EventType.evento,
  };

  bool get isBookmarkedOnly => this == EventFilter.guardados;

  bool matches(CalendarEvent event) {
    if (isBookmarkedOnly) return true;

    final filterType = type;

    if (filterType == null) return true;

    return event.type == filterType;
  }
}
