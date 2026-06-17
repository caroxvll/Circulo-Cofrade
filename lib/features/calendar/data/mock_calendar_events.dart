import '../../../shared/models/calendar_event.dart';



final mockCalendarEvents = <CalendarEvent>[

  CalendarEvent(

    date: DateTime(2026, 6, 2),

    title: 'Salida de Procesión',

    subtitle: 'Hermandad de la Macarena. 20:30',

    type: EventType.procesion,

    dayLabel: 'Salida de\nProcesión',

    time: '20:30',

    organizerLabel: 'Hermandad de la Macarena',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 5),

    title: 'Salida de Procesión',

    subtitle: 'Ntra. Señora de la Misericordia. 18:00',

    type: EventType.procesion,

    time: '18:00',

    organizerLabel: 'Ntra. Señora de la Misericordia',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 6),

    title: 'Traslado al paso',

    subtitle: 'Capilla de los Marineros. 11:00',

    type: EventType.evento,

    dayLabel: 'Traslado',

    time: '11:00',

    location: 'Capilla de los Marineros',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 8),

    title: 'Iguala de costaleros',

    subtitle: 'Casa de la Hermandad. 19:00',

    type: EventType.iguala,

    dayLabel: 'Iguala',

    time: '19:00',

    location: 'Casa de la Hermandad',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 10),

    title: 'Concierto de marchas',

    subtitle: 'Teatro Lope de Vega. 21:00',

    type: EventType.concierto,

    dayLabel: 'Concierto',

    time: '21:00',

    location: 'Teatro Lope de Vega',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 12),

    title: 'Ensayo general de banda',

    subtitle: 'Agrupación Musical. 21:00',

    type: EventType.ensayo,

    dayLabel: 'Ensayo',

    time: '21:00',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 15),

    title: 'Ensayo de nazarenos',

    subtitle: 'Sede de la Hermandad. 20:00',

    type: EventType.ensayo,

    time: '20:00',

    location: 'Sede de la Hermandad',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 20),

    title: 'Iguala de nazarenos',

    subtitle: 'Calle Sierpes. 10:30',

    type: EventType.iguala,

    time: '10:30',

    location: 'Calle Sierpes',

  ),

  CalendarEvent(

    date: DateTime(2026, 6, 24),

    title: 'Procesión de gloria',

    subtitle: 'Corpus Christi. 12:00',

    type: EventType.gloria,

    dayLabel: 'Gloria',

    time: '12:00',

  ),

];


