import '../../../shared/models/forum.dart';

const editorialForumId = 'foro-cofradiero';
const editorialPublicHandle = '@cofradeo';
const editorialPublicName = 'Círculo Cofrade';

/// Tope de cliente. Stream lo recibe por tus (el POST simple corta en 200 MB).
/// Un clip de iPhone en 4K ronda 200 MB en 10 s; 2 GB cubre un par de minutos.
const editorialVideoMaxBytes = 2 * 1024 * 1024 * 1024;

/// Fallback MP4 en R2 si Stream no está activo.
const editorialVideoMaxBytesR2 = 1024 * 1024 * 1024;

String editorialVideoSizeLabel(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb && bytes % gb == 0) return '${bytes ~/ gb} GB';
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  return '${(bytes / mb).round()} MB';
}

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
