import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/calendar_event.dart';
import 'mock_calendar_events.dart';

class CalendarRemoteUnavailableException implements Exception {}

class CalendarRepository {
  CalendarRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isRemote => _client != null;

  Future<List<CalendarEvent>> fetchForMonth(DateTime month) async {
    if (_client == null) return _mockForMonth(month);

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return _fetchBetween(start, end);
  }

  Future<List<CalendarEvent>> fetchBetween(DateTime start, DateTime end) async {
    if (_client == null) {
      return mockCalendarEvents
          .where(
            (e) =>
                !e.date.isBefore(DateTime(start.year, start.month, start.day)) &&
                e.date.isBefore(DateTime(end.year, end.month, end.day)),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
    return _fetchBetween(start, end);
  }

  List<CalendarEvent> _mockForMonth(DateTime month) {
    return mockCalendarEvents
        .where(
          (e) => e.date.year == month.year && e.date.month == month.month,
        )
        .toList();
  }

  Future<List<CalendarEvent>> _fetchBetween(DateTime start, DateTime end) async {
    final rows = await _client!
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .gte('starts_at', start.toUtc().toIso8601String())
        .lt('starts_at', end.toUtc().toIso8601String())
        .order('starts_at', ascending: true);

    return rows.map(_fromRow).toList();
  }

  Future<CalendarEvent> createEvent({
    required String userId,
    required String title,
    required String subtitle,
    required EventType type,
    required DateTime startsAt,
    String? dayLabel,
    String? location,
    String? organizerLabel,
    String? publisherHandle,
  }) async {
    if (_client == null) throw CalendarRemoteUnavailableException();

    final row = await _client!
        .from('calendar_events')
        .insert({
          'title': title,
          'subtitle': subtitle,
          'event_type': type.dbValue,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'day_label': dayLabel,
          'location': location ?? '',
          'organizer_label': organizerLabel ?? '',
          'created_by': userId,
        })
        .select('*, profiles!created_by(handle, display_name)')
        .single();

    return _fromRow(row).copyWith(publisherHandle: publisherHandle);
  }

  Future<CalendarEvent> updateEvent({
    required String eventId,
    required String title,
    required String subtitle,
    required EventType type,
    required DateTime startsAt,
    String? dayLabel,
    String? location,
    String? organizerLabel,
  }) async {
    if (_client == null) throw CalendarRemoteUnavailableException();

    final row = await _client!
        .from('calendar_events')
        .update({
          'title': title,
          'subtitle': subtitle,
          'event_type': type.dbValue,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'day_label': dayLabel,
          'location': location ?? '',
          'organizer_label': organizerLabel ?? '',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', eventId)
        .select('*, profiles!created_by(handle, display_name)')
        .single();

    return _fromRow(row);
  }

  Future<void> deleteEvent(String eventId) async {
    if (_client == null) throw CalendarRemoteUnavailableException();
    await _client!.from('calendar_events').delete().eq('id', eventId);
  }

  Future<List<CalendarEvent>> searchEvents(String rawQuery, {int limit = 12}) async {
    final query = rawQuery.replaceAll('%', '').replaceAll('_', '').trim();
    if (query.isEmpty) return [];

    if (_client == null) {
      final q = query.toLowerCase();
      return mockCalendarEvents
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.subtitle.toLowerCase().contains(q) ||
                e.type.label.toLowerCase().contains(q) ||
                (e.location?.toLowerCase().contains(q) ?? false) ||
                (e.organizerLabel?.toLowerCase().contains(q) ?? false),
          )
          .take(limit)
          .toList();
    }

    final pattern = '%$query%';
    final rows = await _client!
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .or(
          'title.ilike.$pattern,subtitle.ilike.$pattern,location.ilike.$pattern,organizer_label.ilike.$pattern',
        )
        .order('starts_at', ascending: true)
        .limit(limit);

    return rows.map(_fromRow).toList();
  }

  CalendarEvent _fromRow(Map<String, dynamic> row) {
    final startsAt = DateTime.parse(row['starts_at'] as String).toLocal();
    final profile = row['profiles'] as Map<String, dynamic>?;
    final handleRaw = profile?['handle'] as String?;
    final handle = handleRaw == null
        ? null
        : handleRaw.startsWith('@')
            ? handleRaw
            : '@$handleRaw';
    final organizer = row['organizer_label'] as String? ?? '';
    final location = row['location'] as String? ?? '';
    final subtitleRaw = row['subtitle'] as String? ?? '';
    final subtitle = _buildSubtitle(
      subtitle: subtitleRaw,
      location: location,
      organizer: organizer,
    );

    return CalendarEvent(
      id: row['id'] as String,
      date: DateTime(startsAt.year, startsAt.month, startsAt.day),
      title: row['title'] as String,
      subtitle: subtitle,
      type: EventType.fromDb(row['event_type'] as String?),
      dayLabel: row['day_label'] as String?,
      time: DateFormat('HH:mm').format(startsAt),
      location: location.isEmpty ? null : location,
      organizerLabel: organizer.isEmpty ? null : organizer,
      createdById: row['created_by'] as String?,
      publisherHandle: handle,
    );
  }

  String _buildSubtitle({
    required String subtitle,
    required String location,
    required String organizer,
  }) {
    if (subtitle.isNotEmpty) return subtitle;
    final parts = <String>[];
    if (organizer.isNotEmpty) parts.add(organizer);
    if (location.isNotEmpty) parts.add(location);
    return parts.join(' · ');
  }
}

CalendarRepository createCalendarRepository() {
  return CalendarRepository(client: SupabaseBootstrap.client);
}
