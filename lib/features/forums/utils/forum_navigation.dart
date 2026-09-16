import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Abre un hilo desde notificaciones o enlaces.
/// Navegación directa (sin pasar por /foros → lista) para que no se sienta lento.
/// Atrás usa [popForumTopic] → lista del foro.
void openForumTopic(
  BuildContext context, {
  required String forumId,
  required String topicId,
  String querySuffix = '',
}) {
  context.go('/foros/$forumId/tema/$topicId$querySuffix');
}

/// Atrás en detalle de tema: pop si hay pila, si no lista del foro.
void popForumTopic(BuildContext context, {required String forumId}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/foros/$forumId');
  }
}

/// Atrás en lista de temas de un foro: pop si hay pila, si no pilares.
void popForumTopicsList(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/foros');
  }
}
