import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/local_day.dart';
import '../models/event_live_update.dart';
import 'mock_event_live_updates.dart';

class EventLiveUpdateRateLimitedException implements Exception {
  const EventLiveUpdateRateLimitedException();
}

class EventLiveUpdatesRepository {
  EventLiveUpdatesRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _minSecondsBetweenPosts = 60;

  /// Hilo de la cita. Sin ventana de horas: la ficha sigue legible al cerrar el directo.
  Future<List<EventLiveUpdate>> fetchForEvent(String eventId) async {
    final client = _client;
    if (client == null) {
      return mockEventLiveUpdatesFor(eventId);
    }

    final rows = await client
        .from('event_live_updates')
        .select('*, profiles!user_id(handle, avatar_url)')
        .eq('calendar_event_id', eventId)
        .order('created_at', ascending: false)
        .limit(liveJornadaCap);

    return (rows as List)
        .map((row) => updateFromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Avisos que el admin o la Junta han sacado hoy a Para ti.
  Future<List<EventLiveUpdate>> fetchForEvents(
    Iterable<String> eventIds, {
    int limit = paraTiRiverLimit,
  }) async {
    final client = _client;
    final ids = eventIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty || client == null) return const [];

    final since = startOfLocalDay().toUtc();
    final rows = await client
        .from('event_live_updates')
        .select('*, profiles!user_id(handle, avatar_url)')
        .inFilter('calendar_event_id', ids)
        .not('featured_at', 'is', null)
        .gte('featured_at', since.toIso8601String())
        .order('featured_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((row) => updateFromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Payload Realtime (sin join de profiles).
  EventLiveUpdate? fromRealtimeRecord(
    Map<String, dynamic> row, {
    EventLiveUpdate? previous,
  }) {
    final id = row['id']?.toString();
    final eventId = row['calendar_event_id']?.toString();
    final userId = row['user_id']?.toString();
    final createdRaw = row['created_at'] as String?;
    if (id == null ||
        id.isEmpty ||
        eventId == null ||
        eventId.isEmpty ||
        userId == null ||
        userId.isEmpty ||
        createdRaw == null) {
      return null;
    }
    final place = (row['place_label'] as String?)?.trim() ?? '';
    final featuredAt = _featuredAtFrom(row, previous: previous);
    final handleCol = (row['author_handle'] as String?)?.trim();
    final handleRaw = (handleCol != null && handleCol.isNotEmpty)
        ? handleCol
        : (previous?.authorHandle.replaceFirst(RegExp(r'^@'), '') ?? 'cofrade');
    final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
    return EventLiveUpdate(
      id: id,
      calendarEventId: eventId,
      userId: userId,
      authorHandle: handle,
      authorAvatarUrl: previous?.authorAvatarUrl,
      message: (row['message'] as String?)?.trim() ?? '',
      createdAt: DateTime.parse(createdRaw).toLocal(),
      placeLabel: place.isEmpty ? null : place,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      featuredAt: featuredAt,
    );
  }

  Future<EventLiveUpdate> postUpdate({
    required String eventId,
    required String userId,
    required String message,
    String? authorHandle,
    String? placeLabel,
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(message, 'message', 'El mensaje no puede estar vacío');
    }

    if (_client == null) {
      final lastAt = mockLastPostAt(eventId: eventId, userId: userId);
      if (lastAt != null &&
          DateTime.now().difference(lastAt).inSeconds < _minSecondsBetweenPosts) {
        throw const EventLiveUpdateRateLimitedException();
      }
      return addMockEventLiveUpdate(
        eventId: eventId,
        userId: userId,
        authorHandle: _normalizeHandle(authorHandle) ?? '@cofrade',
        message: trimmed,
        placeLabel: placeLabel,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final lastRows = await _client!
        .from('event_live_updates')
        .select('created_at')
        .eq('calendar_event_id', eventId)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (lastRows.isNotEmpty) {
      final lastAt = DateTime.parse(lastRows.first['created_at'] as String);
      if (DateTime.now().toUtc().difference(lastAt.toUtc()).inSeconds <
          _minSecondsBetweenPosts) {
        throw const EventLiveUpdateRateLimitedException();
      }
    }

    final handleForDb = _normalizeHandle(authorHandle)?.replaceFirst('@', '');
    final row = await _client!
        .from('event_live_updates')
        .insert({
          'calendar_event_id': eventId,
          'user_id': userId,
          'message': trimmed,
          'place_label': placeLabel?.trim() ?? '',
          if (handleForDb != null && handleForDb.isNotEmpty)
            'author_handle': handleForDb,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        })
        .select('*, profiles!user_id(handle, avatar_url)')
        .single();

    return updateFromRow(row);
  }

  /// Borra un aviso. Quien lo escribió ya puede; el admin y la Junta, con la policy.
  Future<void> deleteUpdate(String id) async {
    if (_client == null) {
      removeMockEventLiveUpdate(id);
      return;
    }
    await _client.from('event_live_updates').delete().eq('id', id);
  }

  /// Saca o quita un aviso de Para ti. Solo el admin y la Junta, vía RPC.
  Future<DateTime?> setShownInParaTi({
    required String id,
    required bool show,
  }) async {
    if (_client == null) return setMockShownInParaTi(id, show: show);

    final result = await _client.rpc(
      'set_event_live_para_ti',
      params: {'p_id': id, 'p_show': show},
    );
    if (!show || result == null) return null;
    return DateTime.parse(result as String).toLocal();
  }

  EventLiveUpdate updateFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final handleCol = (row['author_handle'] as String?)?.trim();
    final handleRaw = (handleCol != null && handleCol.isNotEmpty)
        ? handleCol
        : (profile?['handle'] as String? ?? 'cofrade');
    final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
    final place = (row['place_label'] as String?)?.trim() ?? '';
    final avatar = (profile?['avatar_url'] as String?)?.trim();

    return EventLiveUpdate(
      id: row['id'] as String,
      calendarEventId: row['calendar_event_id'] as String,
      userId: row['user_id'] as String,
      authorHandle: handle,
      authorAvatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      placeLabel: place.isEmpty ? null : place,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      featuredAt: _featuredAtFrom(row),
    );
  }

  DateTime? _featuredAtFrom(
    Map<String, dynamic> row, {
    EventLiveUpdate? previous,
  }) {
    if (!row.containsKey('featured_at')) return previous?.featuredAt;
    final raw = row['featured_at'];
    if (raw == null) return null;
    return DateTime.parse(raw as String).toLocal();
  }

  static String? _normalizeHandle(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return null;
    return t.startsWith('@') ? t : '@$t';
  }
}

EventLiveUpdatesRepository createEventLiveUpdatesRepository() {
  return EventLiveUpdatesRepository(client: SupabaseBootstrap.client);
}
