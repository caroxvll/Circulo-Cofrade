import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/calendar_event.dart';
import '../models/organizer_logo.dart';
import '../utils/calendar_event_utils.dart';
import 'mock_calendar_events.dart';

class CalendarRemoteUnavailableException implements Exception {}

class CalendarIconTooLargeException implements Exception {}

class CalendarCoverTooLargeException implements Exception {}

class CalendarOrganizerLogoValidationException implements Exception {
  const CalendarOrganizerLogoValidationException();
}

class CalendarOrganizerLogoNotFoundException implements Exception {
  const CalendarOrganizerLogoNotFoundException();
}

class CalendarRepository {
  CalendarRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _eventIconsBucket = 'event-icons';
  static const _eventCoversBucket = 'event-covers';
  static const _maxEventIconBytes = 1024 * 1024;
  static const _maxEventCoverBytes = 3 * 1024 * 1024;

  static final List<OrganizerLogo> _mockOrganizerLogoList =
      _buildMockOrganizerLogoList();

  static List<OrganizerLogo> _buildMockOrganizerLogoList() {
    final byKey = <String, OrganizerLogo>{};
    for (final event in mockCalendarEvents) {
      final label = event.organizerLabel?.trim();
      if (label == null || label.isEmpty) continue;
      final key = normalizeOrganizerKey(label);
      final icon = event.customIconUrl?.trim() ?? '';
      final existing = byKey[key];
      final logoUrl = icon.isNotEmpty
          ? icon
          : (existing?.logoUrl ?? '');
      byKey[key] = OrganizerLogo(
        organizerKey: key,
        displayLabel: label,
        logoUrl: logoUrl,
      );
    }
    final list = byKey.values.toList()
      ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    return list;
  }

  bool get isRemote => _client != null;

  Future<List<CalendarEvent>> fetchForMonth(DateTime month) async {
    if (_client == null) return _mockForMonth(month);

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return _fetchBetween(start, end);
  }

  Future<List<CalendarEvent>> fetchTodayEnsayos() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final events = await fetchBetween(today, tomorrow);
    return events
        .where(
          (e) => e.type == EventType.ensayo && isSameCalendarDay(e.date, today),
        )
        .toList()
      ..sort(compareCalendarEventsByStart);
  }

  Future<CalendarEvent?> fetchEventById(String eventId) async {
    if (_client == null) {
      for (final event in mockCalendarEvents) {
        if (event.id == eventId) return event;
      }
      return null;
    }

    final row = await _client!
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .eq('id', eventId)
        .eq('status', 'published')
        .maybeSingle();

    if (row == null) return null;
    return _fromRow(row);
  }

  Future<List<CalendarEvent>> fetchBetween(DateTime start, DateTime end) async {
    if (_client == null) {
      return mockCalendarEvents
          .where(
            (e) =>
                !e.date.isBefore(
                  DateTime(start.year, start.month, start.day),
                ) &&
                e.date.isBefore(DateTime(end.year, end.month, end.day)),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
    return _fetchBetween(start, end);
  }

  List<CalendarEvent> _mockForMonth(DateTime month) {
    return mockCalendarEvents
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList();
  }

  Future<List<CalendarEvent>> _fetchBetween(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _client!
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .eq('status', 'published')
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
    String? customIconUrl,
    String? coverImageUrl,
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
          'custom_icon_url': customIconUrl ?? '',
          'cover_image_url': coverImageUrl ?? '',
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
    String? customIconUrl,
    String? coverImageUrl,
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
          'custom_icon_url': customIconUrl ?? '',
          'cover_image_url': coverImageUrl ?? '',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', eventId)
        .select('*, profiles!created_by(handle, display_name)')
        .single();

    return _fromRow(row);
  }

  Future<void> deleteEvent(String eventId) async {
    if (_client == null) throw CalendarRemoteUnavailableException();

    final deleted = await _client!
        .from('calendar_events')
        .delete()
        .eq('id', eventId)
        .select('id');

    if (deleted.isEmpty) {
      throw const CalendarEventDeleteFailedException();
    }
  }

  Future<CalendarEvent?> fetchById(String eventId) async {
    if (_client == null) {
      for (final event in mockCalendarEvents) {
        if (event.id == eventId) return event;
      }
      return null;
    }

    final row = await _client!
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .eq('id', eventId)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  Future<String> uploadEventIcon({
    required String userId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (_client == null) throw CalendarRemoteUnavailableException();
    if (bytes.length > _maxEventIconBytes) {
      throw CalendarIconTooLargeException();
    }

    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    final path = '$userId/$fileName';

    await _client!.storage
        .from(_eventIconsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    final publicUrl = _client!.storage
        .from(_eventIconsBucket)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadEventCover({
    required String userId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (_client == null) throw CalendarRemoteUnavailableException();
    if (bytes.length > _maxEventCoverBytes) {
      throw CalendarCoverTooLargeException();
    }

    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    final path = '$userId/$fileName';

    await _client!.storage
        .from(_eventCoversBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    final publicUrl = _client!.storage
        .from(_eventCoversBucket)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<CalendarEvent>> searchEvents(
    String rawQuery, {
    int limit = 12,
    bool upcomingOnly = true,
  }) async {
    final query = rawQuery.replaceAll('%', '').replaceAll('_', '').trim();
    if (query.isEmpty) return [];

    if (_client == null) {
      final q = query.toLowerCase();
      return mockCalendarEvents
          .where(
            (e) =>
                (!_isPastEvent(e) || !upcomingOnly) &&
                (e.title.toLowerCase().contains(q) ||
                e.subtitle.toLowerCase().contains(q) ||
                e.type.label.toLowerCase().contains(q) ||
                (e.location?.toLowerCase().contains(q) ?? false) ||
                (e.organizerLabel?.toLowerCase().contains(q) ?? false)),
          )
          .take(limit)
          .toList();
    }

    final pattern = '%$query%';
    var request = _client!
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .or(
          'title.ilike.$pattern,subtitle.ilike.$pattern,location.ilike.$pattern,organizer_label.ilike.$pattern',
        );

    request = request.eq('status', 'published');
    if (upcomingOnly) {
      request = request.gte(
        'starts_at',
        DateTime.now().toUtc().toIso8601String(),
      );
    }

    final rows = await request.order('starts_at', ascending: true).limit(limit);

    return rows.map(_fromRow).toList();
  }

  bool _isPastEvent(CalendarEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
    if (eventDay.isAfter(today)) return false;
    if (eventDay.isBefore(today)) return true;

    final time = event.time?.trim();
    if (time == null || time.isEmpty) return false;

    final parts = time.split(':');
    if (parts.length < 2) return false;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final startsAt = DateTime(now.year, now.month, now.day, hour, minute);
    return startsAt.isBefore(now);
  }

  Future<String?> fetchOrganizerLogo(String organizerLabel) async {
    final key = normalizeOrganizerKey(organizerLabel);
    if (key.length < 3) return null;

    if (_client == null) {
      for (final item in _mockOrganizerLogoList) {
        if (item.organizerKey == key) return item.logoUrl;
      }
      return null;
    }

    final row = await _client!
        .from('organizer_logos')
        .select('logo_url')
        .eq('organizer_key', key)
        .maybeSingle();
    if (row == null) return null;
    return _nonEmptyUrl(row['logo_url'] as String?);
  }

  Future<void> saveOrganizerLogo({
    required String userId,
    required String organizerLabel,
    required String logoUrl,
  }) async {
    final label = organizerLabel.trim();
    final url = logoUrl.trim();
    if (label.length < 3 || url.isEmpty) return;

    final key = normalizeOrganizerKey(label);
    if (_client == null) {
      final idx = _mockOrganizerLogoList.indexWhere(
        (item) => item.organizerKey == key,
      );
      final entry = OrganizerLogo(
        organizerKey: key,
        displayLabel: label,
        logoUrl: url,
      );
      if (idx >= 0) {
        _mockOrganizerLogoList[idx] = entry;
      } else {
        _mockOrganizerLogoList.add(entry);
        _mockOrganizerLogoList.sort(
          (a, b) => a.displayLabel.compareTo(b.displayLabel),
        );
      }
      return;
    }

    await _client!.from('organizer_logos').upsert({
      'organizer_key': key,
      'display_label': label,
      'logo_url': url,
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateOrganizerLogo({
    required String userId,
    required String organizerKey,
    required String displayLabel,
    String? logoUrl,
    bool propagateToAllEvents = false,
  }) async {
    final label = displayLabel.trim();
    final key = organizerKey.trim();
    if (key.length < 2 || label.length < 3) {
      throw const CalendarOrganizerLogoValidationException();
    }

    if (_client == null) {
      final idx = _mockOrganizerLogoList.indexWhere(
        (item) => item.organizerKey == key,
      );
      if (idx < 0) throw const CalendarOrganizerLogoNotFoundException();
      final url = logoUrl?.trim();
      _mockOrganizerLogoList[idx] = OrganizerLogo(
        organizerKey: key,
        displayLabel: label,
        logoUrl: url ?? _mockOrganizerLogoList[idx].logoUrl,
      );
      return;
    }

    final payload = <String, dynamic>{
      'display_label': label,
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final url = logoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      payload['logo_url'] = url;
    }

    await _client!
        .from('organizer_logos')
        .update(payload)
        .eq('organizer_key', key);

    final resolvedLogoUrl = url?.trim().isNotEmpty == true
        ? url!.trim()
        : await _fetchOrganizerLogoUrl(key);

    if (resolvedLogoUrl.isNotEmpty) {
      await _propagateOrganizerLogoToEvents(
        organizerKey: key,
        displayLabel: label,
        logoUrl: resolvedLogoUrl,
        onlyCreatedBy: propagateToAllEvents ? null : userId,
      );
    } else {
      await _propagateOrganizerLabelToEvents(
        organizerKey: key,
        displayLabel: label,
        onlyCreatedBy: propagateToAllEvents ? null : userId,
      );
    }
  }

  Future<String> _fetchOrganizerLogoUrl(String organizerKey) async {
    if (_client == null) {
      for (final item in _mockOrganizerLogoList) {
        if (item.organizerKey == organizerKey) return item.logoUrl;
      }
      return '';
    }

    final row = await _client!
        .from('organizer_logos')
        .select('logo_url')
        .eq('organizer_key', organizerKey)
        .maybeSingle();
    return row?['logo_url'] as String? ?? '';
  }

  Future<int> _propagateOrganizerLogoToEvents({
    required String organizerKey,
    required String displayLabel,
    required String logoUrl,
    String? onlyCreatedBy,
  }) async {
    final eventIds = await _matchingOrganizerEventIds(
      organizerKey,
      onlyCreatedBy: onlyCreatedBy,
    );
    if (eventIds.isEmpty) return 0;

    final payload = {
      'organizer_label': displayLabel,
      'custom_icon_url': logoUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (_client == null) return 0;

    for (final eventId in eventIds) {
      await _client!.from('calendar_events').update(payload).eq('id', eventId);
    }
    return eventIds.length;
  }

  Future<int> _propagateOrganizerLabelToEvents({
    required String organizerKey,
    required String displayLabel,
    String? onlyCreatedBy,
  }) async {
    final eventIds = await _matchingOrganizerEventIds(
      organizerKey,
      onlyCreatedBy: onlyCreatedBy,
    );
    if (eventIds.isEmpty) return 0;

    final payload = {
      'organizer_label': displayLabel,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (_client == null) return 0;

    for (final eventId in eventIds) {
      await _client!.from('calendar_events').update(payload).eq('id', eventId);
    }
    return eventIds.length;
  }

  Future<List<String>> _matchingOrganizerEventIds(
    String organizerKey, {
    String? onlyCreatedBy,
  }) async {
    if (_client == null) return const [];

    final rows = await _client!
        .from('calendar_events')
        .select('id, organizer_label, created_by')
        .neq('organizer_label', '');

    return rows
        .where(
          (row) =>
              normalizeOrganizerKey(row['organizer_label'] as String? ?? '') ==
                  organizerKey &&
              (onlyCreatedBy == null ||
                  (row['created_by'] as String?) == onlyCreatedBy),
        )
        .map((row) => row['id'] as String)
        .toList();
  }

  Future<void> deleteOrganizerLogo(String organizerKey) async {
    final key = organizerKey.trim();
    if (key.isEmpty) return;

    if (_client == null) {
      _mockOrganizerLogoList.removeWhere((item) => item.organizerKey == key);
      return;
    }

    await _client!.from('organizer_logos').delete().eq('organizer_key', key);
  }

  Future<List<OrganizerLogo>> searchOrganizerLogos(
    String rawQuery, {
    int limit = 30,
  }) async {
    final query = rawQuery.replaceAll('%', '').replaceAll('_', '').trim();

    if (_client == null) {
      final q = query.toLowerCase();
      return _mockOrganizerLogoList
          .where(
            (item) =>
                q.isEmpty ||
                item.displayLabel.toLowerCase().contains(q) ||
                item.organizerKey.contains(q),
          )
          .take(limit)
          .toList();
    }

    final builder = _client!.from('organizer_logos').select(
      'organizer_key, display_label, logo_url',
    );

    final rows = query.isEmpty
        ? await builder.order('display_label', ascending: true).limit(limit)
        : await builder
              .or(
                'display_label.ilike.%$query%,organizer_key.ilike.%$query%',
              )
              .order('display_label', ascending: true)
              .limit(limit);

    return rows
        .map(
          (row) => OrganizerLogo(
            organizerKey: row['organizer_key'] as String,
            displayLabel: (row['display_label'] as String?)?.trim() ?? '',
            logoUrl: row['logo_url'] as String? ?? '',
          ),
        )
        .where((item) => item.displayLabel.isNotEmpty)
        .toList();
  }

  CalendarEvent eventFromRow(Map<String, dynamic> row) => _fromRow(row);

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
      customIconUrl: row['custom_icon_url'] as String?,
      coverImageUrl: _nonEmptyUrl(row['cover_image_url'] as String?),
      status: CalendarEventStatusX.fromDb(row['status'] as String?),
    );
  }

  String? _nonEmptyUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
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
