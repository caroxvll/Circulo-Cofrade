import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/followed_topic.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import '../notifications/notifications_provider.dart';
import '../profile/profile_provider.dart';
import 'data/follows_repository.dart';

final followsRepositoryProvider = Provider<FollowsRepository>((ref) {
  return createFollowsRepository();
});

final followedHashtagsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchFollowedHashtags(user.id);
});

final followedProfilesProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchFollowedProfiles(user.id);
});

final hashtagFollowControllerProvider = Provider<HashtagFollowController>((ref) {
  return HashtagFollowController(ref);
});

final profileFollowControllerProvider = Provider<ProfileFollowController>((ref) {
  return ProfileFollowController(ref);
});

final topicFollowControllerProvider = Provider<TopicFollowController>((ref) {
  return TopicFollowController(ref);
});

final followedTopicsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchFollowedTopics(user.id);
});

final isFollowingTopicProvider =
    FutureProvider.family<bool, String>((ref, topicId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return false;

  return repo.isFollowingTopic(userId: user.id, topicId: topicId);
});

final followedTopicsDetailsProvider =
    FutureProvider<List<FollowedTopic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return [];

  return repo.fetchFollowedTopicsWithDetails(user.id);
});

class HashtagFollowController {
  HashtagFollowController(this._ref);

  final Ref _ref;

  Future<void> toggle({
    required String hashtag,
    required bool currentlyFollowing,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    final repo = _ref.read(followsRepositoryProvider);
    await repo.toggleHashtag(
      userId: user.id,
      hashtag: hashtag,
      follow: !currentlyFollowing,
    );

    _ref.invalidate(followedHashtagsProvider);
    _ref.invalidate(followedProfilesDetailsProvider);
    _ref.invalidate(followedTopicsDetailsProvider);
  }
}

class TopicFollowController {
  TopicFollowController(this._ref);

  final Ref _ref;

  Future<void> toggle({
    required String topicId,
    required bool currentlyFollowing,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    final repo = _ref.read(followsRepositoryProvider);
    await repo.toggleTopic(
      userId: user.id,
      topicId: topicId,
      follow: !currentlyFollowing,
    );

    _ref.invalidate(followedTopicsProvider);
    _ref.invalidate(followedTopicsDetailsProvider);
    _ref.invalidate(isFollowingTopicProvider(topicId));
  }
}

class ProfileFollowController {
  ProfileFollowController(this._ref);

  final Ref _ref;

  Future<void> toggle({
    required String profileId,
    required bool currentlyFollowing,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    final repo = _ref.read(followsRepositoryProvider);
    await repo.toggleProfile(
      userId: user.id,
      profileId: profileId,
      follow: !currentlyFollowing,
    );

    _ref.invalidate(followedProfilesProvider);
    _ref.invalidate(followedProfilesDetailsProvider);
    _ref.invalidate(userProfileProvider(profileId));
    _ref.read(notificationsProvider.notifier).refresh();
  }
}

class FollowRequiresAuthException implements Exception {
  const FollowRequiresAuthException();
}

final followedProfilesDetailsProvider =
    FutureProvider<List<UserProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repo = ref.watch(profileRepositoryProvider);
  if (!repo.isAvailable) return [];

  final ids = await ref.watch(followedProfilesProvider.future);
  final profiles = <UserProfile>[];
  for (final id in ids) {
    final profile = await repo.fetchByUserId(id);
    if (profile != null) profiles.add(profile);
  }
  profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
  return profiles;
});
