import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/local_day.dart';
import '../../shared/models/forum.dart';
import '../cuaresma/cuaresma_ensayos_provider.dart';
import '../cuaresma/models/event_live_update.dart';
import '../cuaresma/utils/cuaresma_topic.dart';
import '../semana_santa/models/ss_live_update.dart';
import '../semana_santa/semana_santa_provider.dart';
import 'forums_provider.dart';

const _circuloForumId = 'foro-cofradiero';

/// Una pieza del río de Para ti. Como mucho [paraTiRiverLimit], de más nuevo a más viejo.
sealed class ParaTiRiverEntry {
  const ParaTiRiverEntry();

  DateTime get at;
}

class ParaTiCuaresmaTweet extends ParaTiRiverEntry {
  const ParaTiCuaresmaTweet(this.update);

  final EventLiveUpdate update;

  @override
  DateTime get at => update.createdAt;
}

class ParaTiSsLive extends ParaTiRiverEntry {
  const ParaTiSsLive(this.update);

  final SsLiveUpdate update;

  @override
  DateTime get at => update.createdAt;
}

class ParaTiHotTopic extends ParaTiRiverEntry {
  const ParaTiHotTopic({required this.topic, required this.activityAt});

  final ForumTopic topic;
  final DateTime activityAt;

  @override
  DateTime get at => activityAt;
}

class ParaTiRiver {
  const ParaTiRiver({required this.entries, required this.settled});

  const ParaTiRiver.empty() : entries = const [], settled = false;

  final List<ParaTiRiverEntry> entries;

  /// Las fuentes ya respondieron, aunque el río esté vacío.
  final bool settled;
}

final _hottestCuaresmaTopicProvider =
    FutureProvider.autoDispose<({ForumTopic topic, DateTime activityAt})?>((
      ref,
    ) async {
      ref.keepAlive();
      final topics = await ref.watch(
        forumTopicsProvider(_circuloForumId).future,
      );
      return ref.read(forumsRepositoryProvider).hottestSeasonTopic(
        cuaresmaCommunityTopics(topics),
      );
    });

/// Río de Para ti: avisos de hoy, directo de Semana Santa y el tema que se mueve.
final paraTiRiverProvider = Provider<ParaTiRiver>((ref) {
  ref.watch(ssLiveRealtimeProvider);

  final tweets = ref.watch(todayCuaresmaLiveTweetsProvider);
  final gate = ref.watch(ssLiveGateProvider);
  final feed = ref.watch(ssLiveRawFeedProvider);
  final hot = ref.watch(_hottestCuaresmaTopicProvider);

  final gateOpen = gate.asData?.value.isOpen == true;
  final settled = (tweets.hasValue || tweets.hasError) &&
      (gate.hasValue || gate.hasError) &&
      (!gateOpen || feed.hasValue || feed.hasError) &&
      (hot.hasValue || hot.hasError);

  final entries = <ParaTiRiverEntry>[
    for (final update in tweets.asData?.value ?? const <EventLiveUpdate>[])
      ParaTiCuaresmaTweet(update),
    if (gateOpen)
      for (final update in feed.asData?.value ?? const <SsLiveUpdate>[])
        ParaTiSsLive(update),
    if (hot.asData?.value case final topic?)
      ParaTiHotTopic(topic: topic.topic, activityAt: topic.activityAt),
  ]..sort((a, b) => b.at.compareTo(a.at));

  return ParaTiRiver(
    entries: entries.take(paraTiRiverLimit).toList(growable: false),
    settled: settled,
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
