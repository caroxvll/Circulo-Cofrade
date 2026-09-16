import '../../../shared/models/forum.dart';

const semanaSantaTopicId = 'circulo-semana-santa';
const semanaSantaSeasonKey = 'semana_santa';

bool isSemanaSantaTopic(ForumTopic topic) =>
    topic.seasonKey == semanaSantaSeasonKey || topic.id == semanaSantaTopicId;

List<ForumTopic> semanaSantaCommunityTopics(List<ForumTopic> topics) {
  final list = topics
      .where((t) => t.seasonKey == semanaSantaSeasonKey && !t.isSystem)
      .toList();
  list.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
  return list;
}
