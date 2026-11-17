import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/calendar_event.dart';
import '../admin/admin_provider.dart';
import '../auth/auth_provider.dart';
import '../calendar/calendar_provider.dart';
import '../permissions/permissions_provider.dart'
    show permissionsRepositoryProvider;
import 'utils/hermandad_board_display.dart';
import 'utils/hermandad_season_acts.dart';

final seasonActsYearProvider = Provider<int>((ref) => currentSeasonActsYear());

final seasonActsEventsProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  ref.watch(calendarEventsEpochProvider);
  final year = ref.watch(seasonActsYearProvider);
  return ref.watch(calendarRepositoryProvider).fetchSeasonActs(year: year);
});

/// Snapshot de actos de temporada para un tablón (por nombre + opcional cuenta).
final hermandadSeasonActsProvider = FutureProvider.autoDispose
    .family<HermandadSeasonActsSnapshot, ({String topicId, String title})>((
      ref,
      key,
    ) async {
  ref.watch(calendarEventsEpochProvider);
  final year = ref.watch(seasonActsYearProvider);
  final events = await ref.watch(seasonActsEventsProvider.future);
  final parsed = parseHermandadTopicTitle(key.title);
  final name = parsed.hermandadName.trim().isEmpty
      ? key.title.trim()
      : parsed.hermandadName.trim();

  String? profileId;
  final currentUser = ref.watch(currentUserProvider);
  final isAdmin = ref.watch(isAdminProvider);
  if (isAdmin) {
    final assignments =
        ref.watch(hermandadAssignmentsProvider).asData?.value ?? const [];
    for (final row in assignments) {
      if (row.topicId == key.topicId) {
        profileId = row.profileId;
        break;
      }
    }
  } else if (currentUser != null) {
    // La propia hermandad puede leer su asignación vía RLS.
    try {
      final ownTopics = await ref
          .watch(permissionsRepositoryProvider)
          .fetchHermandadTopicIds(currentUser.id);
      if (ownTopics.contains(key.topicId)) {
        profileId = currentUser.id;
      }
    } catch (_) {}
  }

  return buildHermandadSeasonActsSnapshot(
    year: year,
    hermandadName: name,
    allSeasonEvents: events,
    topicId: key.topicId,
    profileId: profileId,
  );
});

/// Cobertura Junta: todos los tablones de hermandad × actos de temporada.
final hermandadSeasonActsCoverageProvider =
    FutureProvider.autoDispose<HermandadSeasonActsCoverage>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return HermandadSeasonActsCoverage(
      year: ref.watch(seasonActsYearProvider),
      rows: const [],
    );
  }

  ref.watch(calendarEventsEpochProvider);
  final year = ref.watch(seasonActsYearProvider);
  final repo = ref.watch(calendarRepositoryProvider);
  final permissions = ref.watch(permissionsRepositoryProvider);

  final events = await repo.fetchSeasonActs(year: year);
  final topics = await permissions.fetchHermandadBoardTopics();
  final assignments = await permissions.fetchHermandadAssignments();

  final profileByTopic = <String, String>{
    for (final a in assignments) a.topicId: a.profileId,
  };

  final rows = <HermandadSeasonActsSnapshot>[];
  for (final topic in topics) {
    final parsed = parseHermandadTopicTitle(topic.title);
    final name = parsed.hermandadName.trim().isEmpty
        ? topic.title.trim()
        : parsed.hermandadName.trim();
    final profileId = profileByTopic[topic.id];
    rows.add(
      buildHermandadSeasonActsSnapshot(
        year: year,
        hermandadName: name,
        allSeasonEvents: events,
        topicId: topic.id,
        profileId: profileId,
        hasAccount: profileId != null,
      ),
    );
  }

  rows.sort((a, b) {
    int rank(HermandadSeasonActsSnapshot s) {
      if (!s.hasAccount) return 0;
      if (s.isEmpty) return 1;
      if (!s.isComplete) return 2;
      return 3;
    }

    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.hermandadName.toLowerCase().compareTo(
          b.hermandadName.toLowerCase(),
        );
  });

  return HermandadSeasonActsCoverage(year: year, rows: rows);
});
