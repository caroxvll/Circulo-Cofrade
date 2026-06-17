import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../profile/profile_provider.dart';
import '../../shared/models/user_profile.dart';
import 'data/moderation_repository.dart';

class BlockedProfileEntry {
  const BlockedProfileEntry({
    required this.profile,
    required this.blockedAt,
  });

  final UserProfile profile;
  final DateTime? blockedAt;
}

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return createModerationRepository();
});

final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repo = ref.watch(moderationRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchBlockedUserIds(user.id);
});

final blockedProfilesProvider =
    FutureProvider<List<BlockedProfileEntry>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repo = ref.watch(moderationRepositoryProvider);
  if (!repo.isAvailable) return [];

  final rows = await repo.fetchBlockedProfileRows(user.id);
  final entries = <BlockedProfileEntry>[];

  for (final row in rows) {
    final profileRaw = row['profiles'];
    if (profileRaw is! Map<String, dynamic>) continue;

    final handleRaw = profileRaw['handle'] as String? ?? '';
    final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
    final blockedRaw = row['created_at'] as String?;

    entries.add(
      BlockedProfileEntry(
        profile: UserProfile(
          id: profileRaw['id'] as String,
          handle: handle,
          displayName: profileRaw['display_name'] as String? ?? handleRaw,
          bio: profileRaw['bio'] as String? ?? '',
          publicationCount: 0,
          followerCount: 0,
          avatarIcon: Icons.person,
          address: '',
          foundedLabel: '',
          website: '',
          avatarUrl: profileRaw['avatar_url'] as String?,
        ),
        blockedAt:
            blockedRaw == null ? null : DateTime.parse(blockedRaw).toLocal(),
      ),
    );
  }

  return entries;
});

final profileBlockedProvider =
    FutureProvider.family<bool, String>((ref, profileId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final repo = ref.watch(moderationRepositoryProvider);
  if (!repo.isAvailable) return false;

  return repo.isBlocked(blockerId: user.id, blockedId: profileId);
});

final suspendedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(moderationRepositoryProvider);
  if (!repo.isAvailable) return {};
  return repo.fetchSuspendedUserIds();
});

/// Autores ocultos en foros: bloqueados por el usuario + cuentas suspendidas.
final hiddenForumAuthorIdsProvider = FutureProvider<Set<String>>((ref) async {
  final blocked = await ref.watch(blockedUserIdsProvider.future);
  final suspended = await ref.watch(suspendedUserIdsProvider.future);
  return {...blocked, ...suspended};
});

/// Tras suspender/reactivar: refrescar visibilidad en foros y perfil.
void invalidateAuthorVisibility(WidgetRef ref, {String? profileId}) {
  ref.invalidate(suspendedUserIdsProvider);
  ref.invalidate(hiddenForumAuthorIdsProvider);
  if (profileId != null) {
    ref.invalidate(userProfileProvider(profileId));
  }
}
