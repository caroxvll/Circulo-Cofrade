import 'package:flutter/material.dart';

class OfficialPostCategory {
  const OfficialPostCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

const officialPostCategories = [
  OfficialPostCategory('noticia', 'Noticias', Icons.article_outlined),
  OfficialPostCategory('culto', 'Cultos', Icons.church_outlined),
  OfficialPostCategory('acto', 'Actos', Icons.event_outlined),
  OfficialPostCategory('patrimonio', 'Patrimonio', Icons.account_balance_outlined),
];

String officialCategoryLabel(String value) {
  return switch (value) {
    'culto' => 'Cultos',
    'acto' => 'Actos',
    'patrimonio' => 'Patrimonio',
    _ => 'Noticias',
  };
}

/// Clave de query para deep links al tablón (`?seccion=noticias`).
const hermandadSectionQueryKey = 'seccion';

const _validSectionValues = {'noticia', 'culto', 'acto', 'patrimonio'};

/// Normaliza `?seccion=` de la URL. `null` = Todas las secciones.
String? parseHermandadSectionQuery(String? raw) {
  if (raw == null) return null;
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'todas' || normalized == 'all') {
    return null;
  }
  return switch (normalized) {
    'noticias' || 'noticia' => 'noticia',
    'cultos' || 'culto' => 'culto',
    'actos' || 'acto' => 'acto',
    'patrimonio' => 'patrimonio',
    _ => _validSectionValues.contains(normalized) ? normalized : null,
  };
}

/// Valor legible para la URL (`noticias`, `cultos`…).
String hermandadSectionQueryValue(String? category) {
  if (category == null) return 'todas';
  return switch (category) {
    'culto' => 'cultos',
    'acto' => 'actos',
    'patrimonio' => 'patrimonio',
    _ => 'noticias',
  };
}

bool isHermandadSectionQuery(String? raw) {
  if (raw == null) return false;
  final trimmed = raw.trim().toLowerCase();
  return trimmed.isEmpty ||
      trimmed == 'todas' ||
      trimmed == 'all' ||
      parseHermandadSectionQuery(trimmed) != null;
}
