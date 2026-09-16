import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../models/event_live_update.dart';
import 'mock_event_live_updates.dart';

class EventLiveUpdateRateLimitedException implements Exception {
  const EventLiveUpdateRateLimitedException();
}

class EventLiveUpdatesRepository {
  EventLiveUpdatesRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _minSecondsBetweenPosts = 60;
  static const _feedWindow = Duration(hours: 4);

  Future<List<EventLiveUpdate>> fetchForEvent(String eventId) async {
    if (_client == null) {
      return mockEventLiveUpdatesFor(eventId);
    }

    final since = DateTime.now().toUtc().subtract(_feedWindow);
    final rows = await _client!
        .from('event_live_updates')
        .select('*, profiles!user_id(handle)')
        .eq('calendar_event_id', eventId)
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<EventLiveUpdate> postUpdate({
    required String eventId,
    required String userId,
    required String message,
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
        authorHandle: '@cofrade',
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

    final row = await _client!
        .from('event_live_updates')
        .insert({
          'calendar_event_id': eventId,
          'user_id': userId,
          'message': trimmed,
          'place_label': placeLabel?.trim() ?? '',
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        })
        .select('*, profiles!user_id(handle)')
        .single();

    return _fromRow(row);
  }

  EventLiveUpdate _fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final handleRaw = profile?['handle'] as String? ?? 'cofrade';
    final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
    final place = (row['place_label'] as String?)?.trim() ?? '';

    return EventLiveUpdate(
      id: row['id'] as String,
      calendarEventId: row['calendar_event_id'] as String,
      userId: row['user_id'] as String,
      authorHandle: handle,
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      placeLabel: place.isEmpty ? null : place,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }
}

EventLiveUpdatesRepository createEventLiveUpdatesRepository() {
  return EventLiveUpdatesRepository(client: SupabaseBootstrap.client);
}
