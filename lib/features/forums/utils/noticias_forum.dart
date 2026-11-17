/// Identificador del foro fijo editorial de noticias.
const noticiasForumId = 'noticias';

bool isNoticiasForum(String forumId) => forumId == noticiasForumId;

/// Etiquetas temáticas de una noticia (opción A · UI).
const noticiasCategoryOptions = <({String id, String label})>[
  (id: 'consejo', label: 'Consejo / Institucional'),
  (id: 'hermandades', label: 'Hermandades'),
  (id: 'musica', label: 'Música'),
  (id: 'costaleros', label: 'Costaleros'),
  (id: 'cultura', label: 'Cultura / Patrimonio'),
];

/// Claves válidas (mismo orden que [noticiasCategoryOptions]).
const noticiasCategoryIds = <String>[
  'consejo',
  'hermandades',
  'musica',
  'costaleros',
  'cultura',
];

/// @Deprecated Usar [noticiasCategoryIds].
const noticiasRelatedForumIds = noticiasCategoryIds;

bool isValidNoticiasCategory(String? id) {
  if (id == null || id.isEmpty) return false;
  return noticiasCategoryIds.contains(id);
}

/// @Deprecated Usar [isValidNoticiasCategory].
bool isValidNoticiasRelatedForum(String? forumId) =>
    isValidNoticiasCategory(forumId);

/// Chip corto en cards / detalle.
String noticiasCategoryLabel(String? id) {
  return switch (id) {
    'consejo' => 'Consejo',
    'hermandades' => 'Hermandades',
    'musica' => 'Música',
    'costaleros' => 'Costaleros',
    'cultura' => 'Cultura',
    // Legado (antes de migrar SQL)
    'foro-cofradiero' => 'Consejo',
    'pentagrama-cofrade' => 'Música',
    'martillo-trabajadera' => 'Costaleros',
    _ => 'Actualidad',
  };
}
