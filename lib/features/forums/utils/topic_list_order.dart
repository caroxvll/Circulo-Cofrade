import '../../../shared/models/forum.dart';
import 'noticias_forum.dart';

/// Temas de comunidad en círculos estacionales; solo visibles en el hub.
bool isSeasonCommunityTopic(ForumTopic topic) =>
    topic.seasonKey != null && !topic.isSystem;

/// Pilares absorbidos como temas fijos (no listar en foros).
const hiddenForumPillarIds = {'semana-santa', 'cuaresma', 'glorias'};

/// Foros que se muestran en la app.
///
/// Por defecto solo los abiertos (`isEnabled`). En Junta usa
/// [includeDisabled] para seguir gestionando los ocultos.
List<ForumCategory> visibleForumPillars(
  List<ForumCategory> pillars, {
  bool includeDisabled = false,
}) {
  return [
    for (final pillar in pillars)
      if (!hiddenForumPillarIds.contains(pillar.id) &&
          (includeDisabled || pillar.isEnabled))
        pillar,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

/// Noticias va fuera de «Foros destacados»; el resto son foros de debate.
({ForumCategory? noticias, List<ForumCategory> forums}) splitNoticiasFromForums(
  List<ForumCategory> pillars,
) {
  ForumCategory? noticias;
  final forums = <ForumCategory>[];
  for (final pillar in pillars) {
    if (isNoticiasForum(pillar.id)) {
      noticias = pillar;
    } else {
      forums.add(pillar);
    }
  }
  return (noticias: noticias, forums: forums);
}

class SplitForumTopics {
  const SplitForumTopics({required this.pinned, required this.community});

  final List<ForumTopic> pinned;
  final List<ForumTopic> community;
}

SplitForumTopics splitForumTopics(List<ForumTopic> topics) {
  final pinned = <ForumTopic>[];
  final community = <ForumTopic>[];

  for (final topic in topics) {
    if (topic.isPinned) {
      if (topic.isListed) pinned.add(topic);
    } else {
      community.add(topic);
    }
  }

  return SplitForumTopics(
    pinned: orderPinnedTopics(pinned),
    community: [...community]..sort(_compareByRecency),
  );
}

List<ForumTopic> orderForumTopics(List<ForumTopic> topics) {
  final split = splitForumTopics(topics);
  return [...split.pinned, ...split.community];
}

List<ForumTopic> orderPinnedTopics(List<ForumTopic> pinned) {
  if (pinned.isEmpty) return pinned;

  final sorted = [...pinned]
    ..sort((a, b) {
      final order = a.pinSortOrder.compareTo(b.pinSortOrder);
      if (order != 0) return order;
      return a.title.compareTo(b.title);
    });
  return sorted;
}

int _compareByRecency(ForumTopic a, ForumTopic b) {
  return b.sortTimestamp.compareTo(a.sortTimestamp);
}

enum TopicListSort {
  lastActivity,
  newest,
  mostComments,
  mostViews,
}

extension TopicListSortX on TopicListSort {
  String get label => switch (this) {
    TopicListSort.lastActivity => 'Última actividad',
    TopicListSort.newest => 'Más recientes',
    TopicListSort.mostComments => 'Más comentados',
    TopicListSort.mostViews => 'Más vistos',
  };
}

enum TopicListFilter {
  all,
  resolved,
  open,
}

extension TopicListFilterX on TopicListFilter {
  String get label => switch (this) {
    TopicListFilter.all => 'Todos',
    TopicListFilter.resolved => 'Cerrados',
    TopicListFilter.open => 'Abiertos',
  };
}

bool isTopicNew(ForumTopic topic) {
  final created = topic.createdAt;
  if (created == null) return false;
  return DateTime.now().difference(created).inDays < 3;
}

List<ForumTopic> filterForumTopics(
  List<ForumTopic> topics, {
  String query = '',
  TopicListFilter filter = TopicListFilter.all,
}) {
  final normalized = query.trim().toLowerCase();
  return [
    for (final topic in topics)
      if (_matchesTopicFilter(topic, filter) &&
          _matchesTopicQuery(topic, normalized))
        topic,
  ];
}

bool _matchesTopicFilter(ForumTopic topic, TopicListFilter filter) {
  return switch (filter) {
    TopicListFilter.all => true,
    TopicListFilter.resolved => topic.isClosed || topic.isResolved,
    TopicListFilter.open => !topic.isResolved && !topic.isClosed,
  };
}

bool _matchesTopicQuery(ForumTopic topic, String query) {
  if (query.isEmpty) return true;
  final haystack = [
    topic.title,
    topic.excerpt,
    topic.authorHandle,
  ].join(' ').toLowerCase();
  return haystack.contains(query);
}

List<ForumTopic> sortForumTopics(
  List<ForumTopic> topics,
  TopicListSort sort, {
  bool keepPinnedFirst = true,
}) {
  if (topics.isEmpty) return topics;

  if (!keepPinnedFirst) {
    return [...topics]..sort((a, b) => _compareTopics(a, b, sort));
  }

  final split = splitForumTopics(topics);
  final pinned = split.pinned;
  final community = [...split.community]
    ..sort((a, b) => _compareTopics(a, b, sort));
  return [...pinned, ...community];
}

int _compareTopics(ForumTopic a, ForumTopic b, TopicListSort sort) {
  return switch (sort) {
    TopicListSort.lastActivity => _compareByRecency(a, b),
    TopicListSort.newest => _compareByRecency(a, b),
    TopicListSort.mostComments =>
      b.commentCount.compareTo(a.commentCount) != 0
          ? b.commentCount.compareTo(a.commentCount)
          : _compareByRecency(a, b),
    TopicListSort.mostViews =>
      b.viewCount.compareTo(a.viewCount) != 0
          ? b.viewCount.compareTo(a.viewCount)
          : _compareByRecency(a, b),
  };
}
