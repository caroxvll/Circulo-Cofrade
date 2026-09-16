import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../../shared/models/calendar_event.dart';
import 'data/event_bookmarks_repository.dart';

final eventBookmarksRepositoryProvider = Provider<EventBookmarksRepository>((ref) {
  return createEventBookmarksRepository();
});

String? _bookmarksUserId(Ref ref) {
  final user = ref.read(currentUserProvider);
  if (user != null) return user.id;
  return null;
}

class EventBookmarkIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = _bookmarksUserId(ref);
    if (userId == null) return {};
    return ref.read(eventBookmarksRepositoryProvider).fetchBookmarkIds(userId);
  }

  /// Devuelve `true` si quedó guardado, `false` si se quitó, `null` si no aplica.
  Future<bool?> toggle(CalendarEvent event) async {
    final userId = _bookmarksUserId(ref);
    final eventId = event.id;
    if (userId == null || eventId == null) return null;

    final previous = state.value ?? {};
    final wasBookmarked = previous.contains(eventId);
    final optimistic = wasBookmarked
        ? previous.where((id) => id != eventId).toSet()
        : {...previous, eventId};
    state = AsyncData(optimistic);

    final repo = ref.read(eventBookmarksRepositoryProvider);
    try {
      if (wasBookmarked) {
        await repo.removeBookmark(userId, eventId);
      } else {
        await repo.addBookmark(userId, eventId);
      }
      // Fuente de verdad: lo que quedó en servidor/local tras la operación.
      // No invalidar bookmarkedEventsProvider aquí: ya hace watch de este notifier
      // y un invalidate provoca CircularDependencyError en Riverpod 3.
      final confirmed = await repo.fetchBookmarkIds(userId);
      state = AsyncData(confirmed);
      return confirmed.contains(eventId);
    } catch (e, st) {
      debugPrint('event bookmark toggle failed: $e\n$st');
      state = AsyncData(previous);
      try {
        await repo.replaceLocalIds(userId, previous);
      } catch (_) {}
      rethrow;
    }
  }
}

final eventBookmarkIdsProvider =
    AsyncNotifierProvider<EventBookmarkIdsNotifier, Set<String>>(
  EventBookmarkIdsNotifier.new,
);

final bookmarkedEventsProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  final userId = _bookmarksUserId(ref);
  if (userId == null) return const [];
  ref.watch(eventBookmarkIdsProvider);
  return ref.read(eventBookmarksRepositoryProvider).fetchBookmarkedEvents(userId);
});

bool isEventBookmarked(Set<String> bookmarkIds, CalendarEvent event) {
  final id = event.id;
  return id != null && bookmarkIds.contains(id);
}

bool eventMatchesCalendarFilter(
  CalendarEvent event,
  EventFilter filter,
  Set<String> bookmarkIds,
) {
  if (filter.isBookmarkedOnly) {
    return isEventBookmarked(bookmarkIds, event);
  }
  return filter.matches(event);
}

List<CalendarEvent> applyCalendarEventFilter(
  List<CalendarEvent> events,
  EventFilter filter,
  Set<String> bookmarkIds,
) {
  return events
      .where((e) => eventMatchesCalendarFilter(e, filter, bookmarkIds))
      .toList();
}

List<CalendarEvent> filterBookmarkedEvents(
  List<CalendarEvent> events,
  Set<String> bookmarkIds,
) {
  return events
      .where((event) => isEventBookmarked(bookmarkIds, event))
      .toList();
}
