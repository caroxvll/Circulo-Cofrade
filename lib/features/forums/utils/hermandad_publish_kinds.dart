import 'official_post_categories.dart';

/// Tipo de publicación de la hermandad, el mismo criterio que el portal web.
class HermandadPublishKind {
  const HermandadPublishKind({
    required this.id,
    required this.label,
    required this.officialCategory,
    this.calendarEventType,
  });

  final String id;
  final String label;

  /// Sección del tablón: noticia, culto, acto o patrimonio.
  final String officialCategory;

  /// Tipo de evento si puede salir también en el calendario.
  final String? calendarEventType;

  bool get canCalendar => calendarEventType != null;

  String get boardSectionLabel => officialCategoryLabel(officialCategory);
}

const hermandadPublishKinds = <HermandadPublishKind>[
  HermandadPublishKind(
    id: 'noticia',
    label: 'Nota',
    officialCategory: 'noticia',
  ),
  HermandadPublishKind(
    id: 'culto',
    label: 'Culto',
    officialCategory: 'culto',
    calendarEventType: 'evento',
  ),
  HermandadPublishKind(
    id: 'ensayo',
    label: 'Ensayo',
    officialCategory: 'acto',
    calendarEventType: 'ensayo',
  ),
  HermandadPublishKind(
    id: 'iguala',
    label: 'Igualá',
    officialCategory: 'acto',
    calendarEventType: 'iguala',
  ),
  HermandadPublishKind(
    id: 'muda',
    label: 'Muda',
    officialCategory: 'acto',
    calendarEventType: 'muda',
  ),
  HermandadPublishKind(
    id: 'desarma',
    label: 'Desarma',
    officialCategory: 'acto',
    calendarEventType: 'desarma',
  ),
  HermandadPublishKind(
    id: 'procesion',
    label: 'Procesión',
    officialCategory: 'acto',
    calendarEventType: 'procesion',
  ),
  HermandadPublishKind(
    id: 'acto',
    label: 'Acto',
    officialCategory: 'acto',
    calendarEventType: 'evento',
  ),
  HermandadPublishKind(
    id: 'concierto',
    label: 'Concierto',
    officialCategory: 'acto',
    calendarEventType: 'concierto',
  ),
  HermandadPublishKind(
    id: 'patrimonio',
    label: 'Patrimonio',
    officialCategory: 'patrimonio',
  ),
];

HermandadPublishKind hermandadPublishKindById(String? id) {
  final value = id?.trim();
  for (final kind in hermandadPublishKinds) {
    if (kind.id == value) return kind;
  }
  return hermandadPublishKinds.first;
}

/// Si llega una sección del tablón (`acto`, `culto`…), elige el tipo homónimo.
HermandadPublishKind hermandadPublishKindForSection(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return hermandadPublishKinds.first;
  for (final kind in hermandadPublishKinds) {
    if (kind.id == value) return kind;
  }
  for (final kind in hermandadPublishKinds) {
    if (kind.officialCategory == value) return kind;
  }
  return hermandadPublishKinds.first;
}
