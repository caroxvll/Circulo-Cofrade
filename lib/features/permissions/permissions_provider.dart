import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../shared/models/user_role.dart';
import '../auth/auth_provider.dart';
import '../profile/profile_provider.dart';
import 'data/permissions_repository.dart';

final permissionsRepositoryProvider = Provider<PermissionsRepository>((ref) {
  return createPermissionsRepository();
});

final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return profile?.role == UserRole.admin;
});

/// Admin o moderador asignado a al menos un foro.
final isJuntaMemberProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  final forums = ref.watch(moderatedForumIdsProvider).asData?.value;
  return forums != null && forums.isNotEmpty;
});

/// Compatibilidad con código previo.
final isStaffProvider = Provider<bool>((ref) => ref.watch(isJuntaMemberProvider));

final moderatedForumIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return {};
  if (ref.watch(isAdminProvider)) {
    return ref.watch(permissionsRepositoryProvider).fetchAllForumIds();
  }
  return ref.watch(permissionsRepositoryProvider).fetchModeratedForumIds(userId);
});

/// Suscripción Realtime: actualiza permisos de moderador sin recargar la app.
final permissionsRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(permissionsRepositoryProvider);
  if (user == null || !repo.isAvailable) return;

  final client = SupabaseBootstrap.client;
  if (client == null) return;

  final channel = client
      .channel('forum-moderators-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_moderators',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'profile_id',
          value: user.id,
        ),
        callback: (_) => invalidateUserPermissions(ref),
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

void invalidateUserPermissions(Ref ref) {
  ref.invalidate(moderatedForumIdsProvider);
}

final hermandadTopicIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return {};
  return ref.watch(permissionsRepositoryProvider).fetchHermandadTopicIds(userId);
});

final isForumBannedProvider =
    FutureProvider.autoDispose.family<bool, ({String userId, String forumId})>(
  (ref, params) async {
    return ref.watch(permissionsRepositoryProvider).isBannedFromForum(
          userId: params.userId,
          forumId: params.forumId,
        );
  },
);

bool isForumModerator(WidgetRef ref, String forumId) {
  if (ref.read(isAdminProvider)) return true;
  final forums = ref.read(moderatedForumIdsProvider).asData?.value;
  return forums?.contains(forumId) ?? false;
}

bool canSubmitCalendarEvents(WidgetRef ref) {
  return ref.read(isJuntaMemberProvider);
}

final profileHandleSearchProvider =
    FutureProvider.autoDispose.family<List<ProfileHandleSearchHit>, String>(
  (ref, query) async {
    return ref
        .watch(permissionsRepositoryProvider)
        .searchProfilesByHandlePrefix(query);
  },
);
