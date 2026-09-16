import '../../../shared/models/forum.dart';

const gloriasTopicId = 'circulo-glorias';
const gloriasSeasonKey = 'glorias';

bool isGloriasTopic(ForumTopic topic) =>
    topic.seasonKey == gloriasSeasonKey || topic.id == gloriasTopicId;

List<ForumTopic> gloriasCommunityTopics(List<ForumTopic> topics) {
  final list = topics
      .where((t) => t.seasonKey == gloriasSeasonKey && !t.isSystem)
      .toList();
  list.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
  return list;
}
