import '../../../shared/models/forum.dart';

const editorialForumId = 'foro-cofradiero';
const editorialPublicHandle = '@cofradeo';
const editorialPublicName = 'Círculo Cofrade';

/// Tope de cliente (Stream ~500 MB). R2 sin Stream sigue cortando en edge a 150.
const editorialVideoMaxBytes = 500 * 1024 * 1024;

/// Las editoriales se guardan en forum_topics (para detalle + comentarios),
/// pero no deben listarse como temas del foro: viven en Para ti.

bool isEditorialTopic(ForumTopic topic) => topic.isEditorial;

String editorialViaLabel(ForumTopic topic) {
  final raw = topic.viaAuthorHandle?.trim();
  if (raw == null || raw.isEmpty) return '';
  final handle = raw.startsWith('@') ? raw : '@$raw';
  return 'Vía $handle';
}

bool editorialAllowsConversationSlide(ForumTopic topic) {
  // Imagen/texto sí; vídeo no debe rotar el último comentario.
  return !topic.hasReadyEditorialVideo;
}
