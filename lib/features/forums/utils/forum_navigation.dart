import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Abre un hilo con pila navegable (lista del foro → tema).
/// Necesario al llegar desde notificaciones o enlaces directos.
void openForumTopic(
  BuildContext context, {
  required String forumId,
  required String topicId,
  String querySuffix = '',
}) {
  context.go('/foros');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    context.push('/foros/$forumId');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.push('/foros/$forumId/tema/$topicId$querySuffix');
      }
    });
  });
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
