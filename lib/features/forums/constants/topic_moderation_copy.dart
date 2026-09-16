import '../../../shared/models/forum.dart';

abstract final class TopicModerationCopy {
  static const juntaName =
      'Junta de Gobierno de la Comunidad Circulo Cofrade';

  static const pendingTitle = 'Pendiente de aprobación';
  static const pendingBody =
      'Tu tema está en manos de la $juntaName. '
      'Cuando lo revisen aparecerá en el foro para todos los cofrades.';

  static const rejectedTitle = 'Tema no publicado';
  static const rejectedBody =
      'La $juntaName no ha estimado oportuno publicar este tema.';

  static const submitSuccess =
      'Tema enviado a la $juntaName. Te avisaremos cuando esté publicado.';

  static const publishedTitle = 'Tema publicado';
  static const publishedBody =
      'Tu tema ya es visible en el foro. Los cofrades pueden leerlo y responder.';

  static const profilePendingHint =
      'Tienes temas en revisión por la Junta. Aparecen aquí hasta que se publiquen.';

  static String statusLabel(TopicStatus status) => switch (status) {
        TopicStatus.pending => 'Pendiente de la Junta',
        TopicStatus.published => 'Publicado',
        TopicStatus.rejected => 'No publicado',
      };
}
