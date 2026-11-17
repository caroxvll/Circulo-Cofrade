import '../../../shared/models/forum.dart';

const editorialForumId = 'foro-cofradiero';
const editorialPublicHandle = '@cofradeo';
const editorialPublicName = 'Círculo Cofrade';

/// Límite Fase 2a (MP4 directo en R2). FFmpeg/HLS subirá el techo después.
const editorialVideoMaxBytes = 150 * 1024 * 1024;

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
