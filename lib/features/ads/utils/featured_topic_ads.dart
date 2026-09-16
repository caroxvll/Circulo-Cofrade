import '../../../shared/models/forum.dart';

/// Temas destacados del Círculo donde se puede vender banner.
const featuredTopicAdIds = <String>[
  'circulo-cuaresma',
  'circulo-semana-santa',
  'circulo-glorias',
];

String featuredTopicAdLabel(String topicId) {
  return switch (topicId) {
    'circulo-cuaresma' => 'Cuaresma',
    'circulo-semana-santa' => 'Semana Santa',
    'circulo-glorias' => 'Glorias',
    _ => topicId,
  };
}

bool isFeaturedTopicAdTarget(String topicId) =>
    featuredTopicAdIds.contains(topicId);

bool topicAcceptsFeaturedAds(ForumTopic topic) {
  if (isFeaturedTopicAdTarget(topic.id)) return true;
  final season = topic.seasonKey?.trim();
  if (!topic.isSystem || season == null || season.isEmpty) return false;
  return season == 'cuaresma' ||
      season == 'semana_santa' ||
      season == 'glorias';
}
