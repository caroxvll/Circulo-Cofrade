import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/forum.dart';
import '../cuaresma/utils/cuaresma_topic.dart';
import '../semana_santa/models/ss_live_update.dart';
import '../semana_santa/semana_santa_provider.dart';
import 'forums_provider.dart';

const _circuloForumId = 'foro-cofradiero';

const _paraTiLiveLimit = 5;

/// Lo más vivo de la temporada en Para ti.
/// Con Semana Santa abierta: las últimas publicaciones del directo.
/// Cuaresma sigue con su tema más reciente.
class ParaTiPulse {
  const ParaTiPulse._({
    this.topic,
    this.topicActivityAt,
    this.lives = const [],
  });

  final ForumTopic? topic;
  final DateTime? topicActivityAt;
  final List<SsLiveUpdate> lives;

  bool get hasLive => lives.isNotEmpty;
}

final _hottestCuaresmaTopicProvider =
    FutureProvider.autoDispose<({ForumTopic topic, DateTime activityAt})?>((
      ref,
    ) async {
      ref.keepAlive();
      // La misma lista que el hub: al crear un tema, Para ti se entera.
      final topics = await ref.watch(
        forumTopicsProvider(_circuloForumId).future,
      );
      return ref.read(forumsRepositoryProvider).hottestSeasonTopic(
        cuaresmaCommunityTopics(topics),
      );
    });

/// Directo de Semana Santa (hasta 5) y, si lo hay, el tema caliente de Cuaresma.
final paraTiPulseProvider = Provider<ParaTiPulse?>((ref) {
  ref.watch(ssLiveRealtimeProvider);

  final gate = ref.watch(ssLiveGateProvider).asData?.value;
  final feed = ref.watch(ssLiveRawFeedProvider).asData?.value;
  final hot = ref.watch(_hottestCuaresmaTopicProvider).value;

  final lives = gate?.isOpen == true && feed != null
      ? feed.take(_paraTiLiveLimit).toList(growable: false)
      : const <SsLiveUpdate>[];

  if (lives.isEmpty && hot == null) return null;
  return ParaTiPulse._(
    topic: hot?.topic,
    topicActivityAt: hot?.activityAt,
    lives: lives,
  );
});

/// Última respuesta de un tema, para el deslizamiento del feed.
final latestTopicReplyProvider = FutureProvider.autoDispose
    .family<ForumReply?, String>((ref, topicId) async {
      ref.keepAlive();
      final replies = await ref
          .watch(forumsRepositoryProvider)
          .fetchReplies(topicId, limit: 1);
      if (replies.isEmpty || replies.first.isDeleted) return null;
      final text = replies.first.content.trim();
      final image = replies.first.imageUrl?.trim() ?? '';
      if (text.isEmpty && image.isEmpty) return null;
      return replies.first;
    });
