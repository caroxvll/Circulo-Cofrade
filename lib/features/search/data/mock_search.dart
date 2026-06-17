import 'package:flutter/material.dart';

import '../../../shared/models/forum.dart';
import '../models/search_results.dart';
import '../../forums/data/mock_forums.dart';

class SearchTrend {
  const SearchTrend({
    required this.id,
    required this.hashtag,
    required this.postCount,
    required this.avatarIcon,
  });

  final String id;
  final String hashtag;
  final int postCount;
  final IconData avatarIcon;
}

const mockSearchTrends = <SearchTrend>[
  SearchTrend(
    id: 'viernes-santo',
    hashtag: '#ViernesSanto',
    postCount: 1540,
    avatarIcon: Icons.church,
  ),
  SearchTrend(
    id: 'marchas-cofradas',
    hashtag: '#MarchasCofradas',
    postCount: 982,
    avatarIcon: Icons.music_note,
  ),
  SearchTrend(
    id: 'costaleros',
    hashtag: '#Costaleros',
    postCount: 756,
    avatarIcon: Icons.workspace_premium_outlined,
  ),
  SearchTrend(
    id: 'glorias',
    hashtag: '#Glorias',
    postCount: 421,
    avatarIcon: Icons.wb_sunny_outlined,
  ),
];

const mockRecentSearches = <String>[
  'nueva ruta',
  'itinerario',
  'banda de cornetas',
];

List<ForumTopic> searchTopics(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];

  return mockForumTopics.where((topic) {
    if (!canAccessForum(topic.forumId)) return false;
    return topic.title.toLowerCase().contains(q) ||
        topic.excerpt.toLowerCase().contains(q) ||
        topic.body.toLowerCase().contains(q);
  }).toList();
}

const mockSearchProfiles = <SearchProfileHit>[
  SearchProfileHit(
    id: 'hermandad-sevilla',
    handle: '@hermandad_sevilla',
    displayName: 'Hermandad Sevilla',
    bio: 'Cuenta oficial. Paz y Misericordia.',
  ),
  SearchProfileHit(
    id: 'jose-carpintero',
    handle: '@jose_carpintero',
    displayName: 'José Carpintero',
    bio: 'Costalero y carpintero de pasos.',
  ),
  SearchProfileHit(
    id: 'maria-dolores',
    handle: '@maria_dolores',
    displayName: 'María Dolores',
    bio: 'Nazarena y devota de la Macarena.',
  ),
];

List<SearchProfileHit> searchProfiles(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];

  return mockSearchProfiles.where((profile) {
    return profile.handle.toLowerCase().contains(q) ||
        profile.displayName.toLowerCase().contains(q) ||
        profile.bio.toLowerCase().contains(q);
  }).toList();
}
