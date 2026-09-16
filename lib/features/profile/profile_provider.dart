import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import 'data/profile_from_user.dart';
import 'data/profile_repository.dart';
import '../../shared/models/profile_activity.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return createProfileRepository();
});

final currentUserProfileProvider = FutureProvider<UserProfile>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('Sin sesión');
  }

  final repo = ref.watch(profileRepositoryProvider);
  if (!repo.isAvailable) return userProfileFromAuth(user);

  final remote = await repo.fetchByUserId(user.id);
  return remote ?? userProfileFromAuth(user);
});

final userProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final repo = ref.watch(profileRepositoryProvider);
  if (!repo.isAvailable) return null;
  return repo.fetchByUserId(userId);
});

final userActivityProvider =
    FutureProvider.family<List<ProfileActivity>, String>((ref, userId) async {
  final repo = ref.watch(profileRepositoryProvider);
  if (!repo.isAvailable) return [];
  return repo.fetchUserActivity(userId);
});

final isCurrentUserSuspendedProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return profile?.isSuspended ?? false;
});
