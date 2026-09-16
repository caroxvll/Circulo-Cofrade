import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/calendar_event.dart';
import 'calendar_repository.dart';
import 'event_bookmarks_store.dart';
import 'mock_calendar_events.dart';
import '../utils/calendar_event_utils.dart';

class EventBookmarksRepository {
  EventBookmarksRepository({
    SupabaseClient? client,
    EventBookmarksStore? store,
    CalendarRepository? calendarRepository,
  })  : _client = client,
        _store = store ?? EventBookmarksStore(),
        _calendarRepository =
            calendarRepository ?? CalendarRepository(client: client);

  final SupabaseClient? _client;
  final EventBookmarksStore _store;
  final CalendarRepository _calendarRepository;

  Future<Set<String>> fetchBookmarkIds(String userId) async {
    if (_client == null) {
      return _store.load(userId);
    }

    try {
      final rows = await _client!
          .from('event_bookmarks')
          .select('event_id')
          .eq('user_id', userId);
      final ids = (rows as List)
          .map((row) => row['event_id'] as String)
          .toSet();
      await _store.save(userId, ids);
      return ids;
    } catch (e, st) {
      debugPrint('fetchBookmarkIds failed: $e\n$st');
      return _store.load(userId);
    }
  }

  /// Alinea el caché local con [ids] (p. ej. tras un fallo remoto).
  Future<void> replaceLocalIds(String userId, Set<String> ids) {
    return _store.save(userId, ids);
  }

  Future<List<CalendarEvent>> fetchBookmarkedEvents(String userId) async {
    final ids = await fetchBookmarkIds(userId);
    if (ids.isEmpty) return const [];

    if (_client == null) {
      return mockCalendarEvents
          .where((event) => event.id != null && ids.contains(event.id))
          .toList()
        ..sort(compareCalendarEventsByStart);
    }

    try {
      final rows = await _client!
          .from('event_bookmarks')
          .select(
            'created_at, calendar_events!inner(*, profiles!created_by(handle, display_name))',
          )
          .eq('user_id', userId)
          .eq('calendar_events.status', 'published')
          .order('created_at', ascending: false);

      final events = (rows as List)
          .map((row) {
            final eventRow = row['calendar_events'] as Map<String, dynamic>;
            return _calendarRepository.eventFromRow(eventRow);
          })
          .toList();
      events.sort(compareCalendarEventsByStart);
      return events;
    } catch (e, st) {
      debugPrint('fetchBookmarkedEvents join failed: $e\n$st');
      // Fallback: cargar eventos por id sin embed (más tolerante).
      try {
        final rows = await _client!
            .from('calendar_events')
            .select('*, profiles!created_by(handle, display_name)')
            .inFilter('id', ids.toList())
            .eq('status', 'published');
        final events = (rows as List)
            .map((row) => _calendarRepository.eventFromRow(
                  Map<String, dynamic>.from(row as Map),
                ))
            .toList();
        events.sort(compareCalendarEventsByStart);
        return events;
      } catch (e2, st2) {
        debugPrint('fetchBookmarkedEvents fallback failed: $e2\n$st2');
        return const [];
      }
    }
  }

  Future<void> addBookmark(String userId, String eventId) async {
    if (_client == null) {
      final ids = await _store.load(userId);
      await _store.save(userId, {...ids, eventId});
      return;
    }

    final previous = await _store.load(userId);
    // Optimista en disco solo tras confirmar remoto; si falla, no dejamos basura.
    try {
      await _client!.from('event_bookmarks').upsert(
        {
          'user_id': userId,
          'event_id': eventId,
        },
        onConflict: 'user_id,event_id',
      );
      await _store.save(userId, {...previous, eventId});
    } catch (e, st) {
      debugPrint('addBookmark failed: $e\n$st');
      await _store.save(userId, previous);
      rethrow;
    }
  }

  Future<void> removeBookmark(String userId, String eventId) async {
    if (_client == null) {
      final ids = await _store.load(userId);
      await _store.save(
        userId,
        ids.where((id) => id != eventId).toSet(),
      );
      return;
    }

    final previous = await _store.load(userId);
    try {
      await _client!
          .from('event_bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('event_id', eventId);
      await _store.save(
        userId,
        previous.where((id) => id != eventId).toSet(),
      );
    } catch (e, st) {
      debugPrint('removeBookmark failed: $e\n$st');
      await _store.save(userId, previous);
      rethrow;
    }
  }
}

EventBookmarksRepository createEventBookmarksRepository() {
  final client = SupabaseBootstrap.client;
  return EventBookmarksRepository(
    client: client,
    calendarRepository: createCalendarRepository(),
  );
}
