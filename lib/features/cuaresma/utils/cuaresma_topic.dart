import '../../../shared/models/forum.dart';

const cuaresmaTopicId = 'circulo-cuaresma';
const cuaresmaSeasonKey = 'cuaresma';

bool isCuaresmaTopic(ForumTopic topic) =>
    topic.seasonKey == cuaresmaSeasonKey || topic.id == cuaresmaTopicId;

List<ForumTopic> cuaresmaCommunityTopics(List<ForumTopic> topics) {
  final list = topics
      .where((t) => t.seasonKey == cuaresmaSeasonKey && !t.isSystem)
      .toList();
  list.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
  return list;
}
