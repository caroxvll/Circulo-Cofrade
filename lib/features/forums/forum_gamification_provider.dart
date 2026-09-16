import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/forum_gamification_repository.dart';

final forumGamificationRepositoryProvider =
    Provider<ForumGamificationRepository>((ref) {
  return createForumGamificationRepository();
});

final cofradeGamificationProvider = FutureProvider.autoDispose
    .family<CofradeGamificationSnapshot, String>((ref, userId) async {
  final repo = ref.watch(forumGamificationRepositoryProvider);
  if (!repo.isAvailable) return CofradeGamificationSnapshot.empty;
  return repo.fetchSnapshot(userId);
});
