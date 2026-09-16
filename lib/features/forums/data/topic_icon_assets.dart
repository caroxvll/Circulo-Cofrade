import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../shared/models/forum.dart';
import 'forum_icons.dart';

/// Imagen empaquetada en la app para un tema fijo (si existe).
String? topicBundledIconAsset(ForumTopic topic) {
  return switch (topic.id) {
    'martillo-cambio-capataces' => AppAssets.forumMartilloIcon,
    'circulo-cuaresma' => AppAssets.topicCuaresmaIcon,
    'circulo-semana-santa' => AppAssets.topicSemanaSantaIcon,
    'circulo-glorias' => AppAssets.topicGloriasIcon,
    _ => null,
  };
}

IconData topicDisplayIcon(ForumTopic topic) {
  return forumIconFromKey(topic.iconKey, fallback: topic.avatarIcon);
}

/// URL remota o ruta `assets/...` para la portada del tema.
String? topicCoverImageSource(ForumTopic topic) {
  final cover = topic.coverImageUrl?.trim();
  if (cover != null && cover.isNotEmpty) return cover;
  return topicBundledIconAsset(topic);
}

bool topicCoverIsAsset(String source) => source.startsWith('assets/');
