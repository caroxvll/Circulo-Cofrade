/// Identificador del foro fijo editorial de noticias.
const noticiasForumId = 'noticias';

bool isNoticiasForum(String forumId) => forumId == noticiasForumId;

/// Foros a los que se puede etiquetar una noticia (orden de UI).
const noticiasRelatedForumIds = <String>[
  'foro-cofradiero',
  'pentagrama-cofrade',
  'martillo-trabajadera',
  'hermandades',
];

bool isValidNoticiasRelatedForum(String? forumId) {
  if (forumId == null || forumId.isEmpty) return false;
  return noticiasRelatedForumIds.contains(forumId);
}
