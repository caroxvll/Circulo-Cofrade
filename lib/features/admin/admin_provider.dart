import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../shared/models/calendar_event.dart';
import '../../shared/models/forum.dart';
import '../forums/forums_provider.dart';
import '../forums/utils/topic_list_order.dart';
import '../permissions/data/permissions_repository.dart';
import '../permissions/permissions_provider.dart';
import 'data/admin_repository.dart';
import 'junta_modules.dart';

export '../permissions/permissions_provider.dart'
    show isAdminProvider, isJuntaMemberProvider, isStaffProvider;

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return createAdminRepository();
});

final pendingTopicsProvider = FutureProvider<List<ForumTopic>>((ref) async {
  if (!ref.watch(isJuntaMemberProvider)) return [];
  final isAdmin = ref.watch(isAdminProvider);
  final moderatedForums = await ref.watch(moderatedForumIdsProvider.future);
  final topics = await ref.watch(adminRepositoryProvider).fetchPendingTopics();
  if (isAdmin) return topics;
  return topics.where((t) => moderatedForums.contains(t.forumId)).toList();
});

/// Realtime: cola de temas pendientes de la Junta.
final pendingTopicsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(isJuntaMemberProvider)) return;
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? debounce;
  void scheduleRefresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      ref.invalidate(pendingTopicsProvider);
    });
  }

  final channel = client
      .channel('junta-pending-topics')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_topics',
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          final status = record['status']?.toString();
          // Altas pendientes, aprobaciones/rechazos y cambios de portada.
          if (status == 'pending' ||
              payload.eventType == PostgresChangeEvent.update ||
              payload.eventType == PostgresChangeEvent.delete) {
            scheduleRefresh();
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});

final pendingReportsProvider =
    FutureProvider<List<ModerationReport>>((ref) async {
  if (!ref.watch(isJuntaMemberProvider)) return [];
  final isAdmin = ref.watch(isAdminProvider);
  final moderatedForums = await ref.watch(moderatedForumIdsProvider.future);
  final reports =
      await ref.watch(adminRepositoryProvider).fetchPendingReports();
  if (isAdmin) return reports;
  return reports
      .where(
        (r) =>
            r.targetForumId != null &&
            moderatedForums.contains(r.targetForumId),
      )
      .toList();
});

final pendingReportGroupsProvider =
    FutureProvider<List<ModerationReportGroup>>((ref) async {
  final reports = await ref.watch(pendingReportsProvider.future);
  return groupModerationReports(reports);
});

final pendingCalendarEventsProvider =
    FutureProvider<List<CalendarEvent>>((ref) async {
  if (!ref.watch(isAdminProvider)) return [];
  return ref.watch(adminRepositoryProvider).fetchPendingCalendarEvents();
});

final closeRequestedTopicsProvider =
    FutureProvider<List<ForumTopic>>((ref) async {
  if (!ref.watch(isJuntaMemberProvider)) return [];
  final isAdmin = ref.watch(isAdminProvider);
  final moderatedForums = await ref.watch(moderatedForumIdsProvider.future);
  final topics =
      await ref.watch(adminRepositoryProvider).fetchCloseRequestedTopics();
  if (isAdmin) return topics;
  return topics.where((t) => moderatedForums.contains(t.forumId)).toList();
});

const rejectedTopicsPageSize = 20;

class RejectedTopicsPage {
  const RejectedTopicsPage({
    required this.topics,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<ForumTopic> topics;
  final bool hasMore;
  final bool isLoadingMore;

  RejectedTopicsPage copyWith({
    List<ForumTopic>? topics,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return RejectedTopicsPage(
      topics: topics ?? this.topics,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class RejectedTopicsNotifier extends AsyncNotifier<RejectedTopicsPage> {
  @override
  Future<RejectedTopicsPage> build() async {
    if (!ref.watch(isJuntaMemberProvider)) {
      return const RejectedTopicsPage(topics: [], hasMore: false);
    }
    final batch = await _fetchPage(offset: 0);
    return RejectedTopicsPage(
      topics: batch,
      hasMore: batch.length >= rejectedTopicsPageSize,
    );
  }

  Future<List<ForumTopic>> _fetchPage({required int offset}) async {
    final isAdmin = ref.read(isAdminProvider);
    final moderatedForums = await ref.read(moderatedForumIdsProvider.future);
    return ref.read(adminRepositoryProvider).fetchRejectedTopics(
          offset: offset,
          limit: rejectedTopicsPageSize,
          forumIds: isAdmin ? null : moderatedForums.toList(),
        );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final batch = await _fetchPage(offset: current.topics.length);
      state = AsyncData(
        RejectedTopicsPage(
          topics: [...current.topics, ...batch],
          hasMore: batch.length >= rejectedTopicsPageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> deleteTopic(String topicId) async {
    await ref.read(adminRepositoryProvider).deleteTopic(topicId);
    final current = state.asData?.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(
      current.copyWith(
        topics: current.topics.where((t) => t.id != topicId).toList(),
      ),
    );
  }
}

final rejectedTopicsProvider =
    AsyncNotifierProvider<RejectedTopicsNotifier, RejectedTopicsPage>(
  RejectedTopicsNotifier.new,
);

final forumModeratorAssignmentsProvider =
    FutureProvider<List<ForumModeratorAssignment>>((ref) async {
  if (!ref.watch(isAdminProvider)) return [];
  return ref
      .watch(permissionsRepositoryProvider)
      .fetchAllModeratorAssignments();
});

final hermandadAssignmentsProvider =
    FutureProvider<List<HermandadTopicAssignment>>((ref) async {
  if (!ref.watch(isAdminProvider)) return [];
  return ref.watch(permissionsRepositoryProvider).fetchHermandadAssignments();
});

final hermandadBoardTopicsProvider =
    FutureProvider<List<({String id, String title})>>((ref) async {
  if (!ref.watch(isAdminProvider)) return [];
  return ref.watch(permissionsRepositoryProvider).fetchHermandadBoardTopics();
});

final adminPillarsProvider = FutureProvider<List<ForumCategory>>((ref) async {
  if (!ref.watch(isAdminProvider)) return [];
  final pillars = await ref.watch(adminRepositoryProvider).fetchPillars();
  return visibleForumPillars(pillars, includeDisabled: true);
});

final pinnedSystemTopicsProvider = FutureProvider<List<ForumTopic>>((ref) async {
  if (!ref.watch(isAdminProvider)) return [];
  return ref.watch(forumsRepositoryProvider).fetchPinnedSystemTopics();
});

class JuntaSelectedModule extends Notifier<JuntaModule> {
  @override
  JuntaModule build() => JuntaModule.overview;

  void select(JuntaModule module) => state = module;
}

final juntaSelectedModuleProvider =
    NotifierProvider<JuntaSelectedModule, JuntaModule>(
  JuntaSelectedModule.new,
);
