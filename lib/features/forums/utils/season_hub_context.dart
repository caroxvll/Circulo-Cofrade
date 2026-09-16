import '../../../shared/models/forum.dart';
import '../../cuaresma/utils/cuaresma_topic.dart';
import '../../glorias/utils/glorias_topic.dart';
import '../../semana_santa/utils/semana_santa_topic.dart';

/// Etiqueta corta de hub estacional (`cuaresma`, `semana_santa`, `glorias`).
String? seasonHubLabel(String? seasonKey) {
  return switch (seasonKey?.trim()) {
    cuaresmaSeasonKey => 'Cuaresma',
    semanaSantaSeasonKey => 'Semana Santa',
    gloriasSeasonKey => 'Glorias',
    _ => null,
  };
}

/// Id del tema-sistema hub de esa temporada.
String? seasonHubTopicId(String? seasonKey) {
  return switch (seasonKey?.trim()) {
    cuaresmaSeasonKey => cuaresmaTopicId,
    semanaSantaSeasonKey => semanaSantaTopicId,
    gloriasSeasonKey => gloriasTopicId,
    _ => null,
  };
}

/// Temas de comunidad dentro de un hub estacional (no el hub en sí).
bool isSeasonCommunityTopicDetail(ForumTopic topic) {
  if (topic.isSystem) return false;
  return seasonHubLabel(topic.seasonKey) != null;
}
