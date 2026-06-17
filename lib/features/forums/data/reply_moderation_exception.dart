class ReplyModerationException implements Exception {
  const ReplyModerationException(this.code);

  final String code;

  static const authRequired = 'auth_required';
  static const notFound = 'not_found';
  static const forbidden = 'forbidden';
  static const deleted = 'deleted';
  static const editWindowExpired = 'edit_window_expired';
  static const hasReplies = 'has_replies';
  static const invalidContent = 'invalid_content';

  String get userMessage => switch (code) {
        editWindowExpired =>
          'Solo puedes editar durante 30 minutos tras publicar.',
        hasReplies =>
          'No puedes editar una respuesta que ya tiene contestaciones.',
        deleted => 'Este comentario ya no está disponible.',
        invalidContent => 'El texto debe tener entre 1 y 4000 caracteres.',
        forbidden => 'No tienes permiso para esta acción.',
        notFound => 'No se encontró la respuesta.',
        authRequired => 'Inicia sesión para continuar.',
        _ => 'No se pudo completar la acción.',
      };

  static ReplyModerationException? fromPostgrestMessage(String? message) {
    if (message == null) return null;
    for (final code in [
      editWindowExpired,
      hasReplies,
      deleted,
      invalidContent,
      forbidden,
      notFound,
      authRequired,
    ]) {
      if (message.contains(code)) {
        return ReplyModerationException(code);
      }
    }
    return null;
  }
}
