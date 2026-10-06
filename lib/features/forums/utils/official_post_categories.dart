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

/// Normaliza `?seccion=` de la URL. Por defecto Noticias.
String parseHermandadSectionQuery(String? raw) {
  if (raw == null) return 'noticia';
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'todas' || normalized == 'all') {
    return 'noticia';
  }
  return switch (normalized) {
    'noticias' || 'noticia' => 'noticia',
    'cultos' || 'culto' => 'culto',
    'actos' || 'acto' => 'acto',
    'patrimonio' => 'patrimonio',
    _ => _validSectionValues.contains(normalized) ? normalized : 'noticia',
  };
}

/// Valor legible para la URL (`noticias`, `cultos`…).
String hermandadSectionQueryValue(String category) {
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
  if (trimmed.isEmpty || trimmed == 'todas' || trimmed == 'all') return true;
  return switch (trimmed) {
    'noticias' ||
    'noticia' ||
    'cultos' ||
    'culto' ||
    'actos' ||
    'acto' ||
    'patrimonio' =>
      true,
    _ => _validSectionValues.contains(trimmed),
  };
}
