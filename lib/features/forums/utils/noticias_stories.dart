import '../../../shared/models/forum.dart';

/// Una ficha del listado de Noticias.
/// Si hay varias, son la misma noticia unificada: la primera en publicarse
/// va la primera en el carrusel.
class NoticiasStory {
  const NoticiasStory(this.topics);

  final List<ForumTopic> topics;

  ForumTopic get lead => topics.first;

  bool get isGrouped => topics.length > 1;

  int get latestTimestamp {
    var latest = 0;
    for (final topic in topics) {
      if (topic.sortTimestamp > latest) latest = topic.sortTimestamp;
    }
    return latest;
  }
}

/// Agrupa por [ForumTopic.newsGroupId]. Dentro del grupo, orden de llegada.
/// En el listado, la ficha ocupa el puesto de la publicación más reciente.
List<NoticiasStory> groupNoticiasForFeed(List<ForumTopic> topics) {
  final byGroup = <String, List<ForumTopic>>{};
  final stories = <NoticiasStory>[];

  for (final topic in topics) {
    if (!topic.isListed || !topic.isPublished) continue;
    final groupId = topic.newsGroupId;
    if (groupId == null || groupId.isEmpty) {
      stories.add(NoticiasStory([topic]));
      continue;
    }
    byGroup.putIfAbsent(groupId, () => []).add(topic);
  }

  for (final members in byGroup.values) {
    members.sort((a, b) => a.sortTimestamp.compareTo(b.sortTimestamp));
    stories.add(NoticiasStory(List<ForumTopic>.unmodifiable(members)));
  }

  stories.sort((a, b) {
    final byTime = b.latestTimestamp.compareTo(a.latestTimestamp);
    if (byTime != 0) return byTime;
    return a.lead.id.compareTo(b.lead.id);
  });
  return stories;
}

/// Hermanas de [topic] ya cargadas en el listado, con [topic] incluido.
NoticiasStory storyForTopic(List<ForumTopic>? all, ForumTopic topic) {
  final groupId = topic.newsGroupId;
  if (all == null || groupId == null || groupId.isEmpty) {
    return NoticiasStory([topic]);
  }

  final members = <ForumTopic>[
    for (final candidate in all)
      if (candidate.newsGroupId == groupId &&
          candidate.isPublished &&
          candidate.id != topic.id)
        candidate,
  ];
  members.add(topic);
  members.sort((a, b) => a.sortTimestamp.compareTo(b.sortTimestamp));
  return NoticiasStory(members);
}
