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

/// Perfiles a los que el usuario actual ha enviado solicitud (pendiente).
final pendingOutgoingFollowRequestsProvider =
    FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchPendingOutgoingFollowRequests(user.id);
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

final forumFollowControllerProvider = Provider<ForumFollowController>((ref) {
  return ForumFollowController(ref);
});

final isFollowingForumProvider =
    FutureProvider.family<bool, String>((ref, forumId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return false;

  return repo.isFollowingForum(userId: user.id, forumId: forumId);
});

final followedTopicsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchFollowedTopics(user.id);
});

final followingCountProvider = FutureProvider<int>((ref) async {
  final profiles = await ref.watch(followedProfilesProvider.future);
  return profiles.length;
});

final isFollowingTopicProvider =
    FutureProvider.family<bool, String>((ref, topicId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return false;

  return repo.isFollowingTopic(userId: user.id, topicId: topicId);
});

/// Conteo de seguidores de un hilo / tablón de hermandad.
final topicFollowerCountProvider =
    FutureProvider.family<int, String>((ref, topicId) async {
  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return 0;
  return repo.countTopicFollowers(topicId);
});

final topicFollowNotifyCategoriesProvider =
    FutureProvider.family<List<String>?, String>((ref, topicId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return null;

  return repo.fetchTopicFollowNotifyCategories(
    userId: user.id,
    topicId: topicId,
  );
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

  void _invalidateTopicFollow(String topicId) {
    _ref.invalidate(followedTopicsProvider);
    _ref.invalidate(followedTopicsDetailsProvider);
    _ref.invalidate(isFollowingTopicProvider(topicId));
    _ref.invalidate(topicFollowNotifyCategoriesProvider(topicId));
    _ref.invalidate(topicFollowerCountProvider(topicId));
  }

  Future<void> toggle({
    required String topicId,
    required bool currentlyFollowing,
    List<String>? notifyOfficialCategories,
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
      notifyOfficialCategories: notifyOfficialCategories,
    );

    _invalidateTopicFollow(topicId);
  }

  Future<void> updateNotifyCategories({
    required String topicId,
    required List<String>? notifyOfficialCategories,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    final repo = _ref.read(followsRepositoryProvider);
    await repo.updateTopicFollowNotifyCategories(
      userId: user.id,
      topicId: topicId,
      notifyOfficialCategories: notifyOfficialCategories,
    );

    _invalidateTopicFollow(topicId);
  }
}

class ForumFollowController {
  ForumFollowController(this._ref);

  final Ref _ref;

  Future<void> toggle({
    required String forumId,
    required bool currentlyFollowing,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    final repo = _ref.read(followsRepositoryProvider);
    await repo.toggleForum(
      userId: user.id,
      forumId: forumId,
      follow: !currentlyFollowing,
    );

    _ref.invalidate(isFollowingForumProvider(forumId));
  }
}

class ProfileFollowController {
  ProfileFollowController(this._ref);

  final Ref _ref;

  void _invalidateProfileFollow(String profileId) {
    _ref.invalidate(followedProfilesProvider);
    _ref.invalidate(followedProfilesDetailsProvider);
    _ref.invalidate(pendingOutgoingFollowRequestsProvider);
    _ref.invalidate(followingCountProvider);
    _ref.invalidate(myFollowersDetailsProvider);
    _ref.invalidate(userProfileProvider(profileId));
    _ref.invalidate(userFollowersDetailsProvider(profileId));
    _ref.invalidate(userFollowingCountProvider(profileId));
    _ref.read(notificationsProvider.notifier).refresh();
  }

  /// Seguir / dejar de seguir. En cuentas privadas crea o cancela solicitud.
  Future<void> toggle({
    required String profileId,
    required bool currentlyFollowing,
    bool isPrivate = false,
    bool currentlyRequested = false,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    final repo = _ref.read(followsRepositoryProvider);

    if (currentlyFollowing) {
      await repo.toggleProfile(
        userId: user.id,
        profileId: profileId,
        follow: false,
      );
    } else if (currentlyRequested) {
      await repo.cancelFollowRequest(
        userId: user.id,
        profileId: profileId,
      );
    } else if (isPrivate) {
      await repo.requestFollow(
        userId: user.id,
        profileId: profileId,
      );
    } else {
      await repo.toggleProfile(
        userId: user.id,
        profileId: profileId,
        follow: true,
      );
    }

    _invalidateProfileFollow(profileId);
  }

  Future<void> acceptRequest(String requestId, {String? requesterId}) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    await _ref.read(followsRepositoryProvider).acceptFollowRequest(requestId);
    _ref.invalidate(myFollowersDetailsProvider);
    _ref.invalidate(followedProfilesProvider);
    if (requesterId != null) {
      _ref.invalidate(userProfileProvider(requesterId));
      _ref.invalidate(userFollowingCountProvider(requesterId));
      _ref.invalidate(userFollowersDetailsProvider(user.id));
    }
    _ref.read(notificationsProvider.notifier).refresh();
  }

  Future<void> rejectRequest(String requestId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const FollowRequiresAuthException();
    }

    await _ref.read(followsRepositoryProvider).rejectFollowRequest(requestId);
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

final myFollowersDetailsProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final followsRepo = ref.watch(followsRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  if (!followsRepo.isAvailable || !profileRepo.isAvailable) return [];

  final ids = await followsRepo.fetchFollowerProfileIds(user.id);
  final profiles = <UserProfile>[];
  for (final id in ids) {
    final profile = await profileRepo.fetchByUserId(id);
    if (profile != null) profiles.add(profile);
  }
  return profiles;
});

/// Nº de cuentas que sigue un usuario (perfil ajeno).
final userFollowingCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final repo = ref.watch(followsRepositoryProvider);
  if (!repo.isAvailable) return 0;
  final ids = await repo.fetchFollowedProfiles(userId);
  return ids.length;
});

/// Seguidores de un usuario concreto (cotilleo).
final userFollowersDetailsProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, String>((ref, userId) async {
  final followsRepo = ref.watch(followsRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  if (!followsRepo.isAvailable || !profileRepo.isAvailable) return [];

  final ids = await followsRepo.fetchFollowerProfileIds(userId);
  final profiles = <UserProfile>[];
  for (final id in ids) {
    final profile = await profileRepo.fetchByUserId(id);
    if (profile != null) profiles.add(profile);
  }
  return profiles;
});

/// Cuentas que sigue un usuario concreto (cotilleo).
final userFollowingDetailsProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, String>((ref, userId) async {
  final followsRepo = ref.watch(followsRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  if (!followsRepo.isAvailable || !profileRepo.isAvailable) return [];

  final ids = await followsRepo.fetchFollowedProfiles(userId);
  final profiles = <UserProfile>[];
  for (final id in ids) {
    final profile = await profileRepo.fetchByUserId(id);
    if (profile != null) profiles.add(profile);
  }
  profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
  return profiles;
});
