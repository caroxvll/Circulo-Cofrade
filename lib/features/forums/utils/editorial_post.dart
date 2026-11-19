import '../../../shared/models/forum.dart';

const editorialForumId = 'foro-cofradiero';
const editorialPublicHandle = '@cofradeo';
const editorialPublicName = 'Círculo Cofrade';

/// Tope de cliente. Stream lo recibe por tus (el POST simple corta en 200 MB).
/// R2, si Stream no está activo, sigue cortando en 150 MB.
const editorialVideoMaxBytes = 500 * 1024 * 1024;

/// Fotos de una publicación de Para ti. La primera queda delante del montón.
const editorialGalleryMaxImages = 4;

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
