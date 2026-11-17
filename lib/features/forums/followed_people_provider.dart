import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/profile_activity.dart';
import '../../shared/models/user_profile.dart';
import '../profile/profile_provider.dart';
import '../search/follows_provider.dart';

class FollowedPersonPost {
  const FollowedPersonPost({
    required this.profile,
    required this.activity,
    required this.at,
  });

  final UserProfile profile;
  final ProfileActivity activity;
  final DateTime at;
}

/// Lo último publicado por cada cuenta que sigues, de más nuevo a más antiguo.
final followedPeoplePostsProvider =
    FutureProvider.autoDispose<List<FollowedPersonPost>>((ref) async {
  ref.keepAlive();
  final profiles = await ref.watch(followedProfilesDetailsProvider.future);
  final visible = profiles.where((profile) => !profile.isSuspended).toList();
  if (visible.isEmpty) return [];

  final repo = ref.watch(profileRepositoryProvider);
  final latest = await Future.wait([
    for (final profile in visible) repo.fetchLatestPublicActivity(profile.id),
  ]);

  final posts = <FollowedPersonPost>[];
  for (var i = 0; i < visible.length; i++) {
    final item = latest[i];
    if (item == null) continue;
    posts.add(
      FollowedPersonPost(
        profile: visible[i],
        activity: item.activity,
        at: item.at,
      ),
    );
  }
  posts.sort((a, b) => b.at.compareTo(a.at));
  return posts;
});
