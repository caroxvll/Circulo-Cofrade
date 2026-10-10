import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../forums_provider.dart';
import '../topic_replies_provider.dart';

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

/// Dispara la carga de tema + primera página de respuestas *antes* de navegar.
/// Así el skeleton se acorta o desaparece si la red responde a tiempo.
void prefetchForumTopic(WidgetRef ref, {required String forumId, required String topicId}) {
  final key = ForumTopicKey(forumId: forumId, topicId: topicId);
  // ignore: unused_result — solo calentamos caché de Riverpod
  ref.read(forumTopicProvider(key).future);
  // ignore: unused_result
  ref.read(topicRepliesFirstPageProvider(topicId).future);
}

/// Calienta la lista de temas del foro *antes* del push (1ª visita menos fría).
void prefetchForumTopicsList(WidgetRef ref, {required String forumId}) {
  // ignore: unused_result
  ref.read(forumTopicsProvider(forumId).future);
}

/// Prefetch + push. Usar desde listas (tarjetas de tema / tablón).
Future<void> pushForumTopic(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
  required String topicId,
}) {
  prefetchForumTopic(ref, forumId: forumId, topicId: topicId);
  return context.push('/foros/$forumId/tema/$topicId');
}

/// Prefetch lista + push al pilar (Noticias, Hermandades, etc.).
Future<void> pushForumTopicsList(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
}) {
  prefetchForumTopicsList(ref, forumId: forumId);
  return context.push('/foros/$forumId');
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
