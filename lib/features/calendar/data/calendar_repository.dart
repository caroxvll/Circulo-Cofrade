import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/calendar_event.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../../forums/utils/hermandad_season_acts.dart';
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

  /// Igualás, ensayos, mudas y desarmás de la temporada de Semana Santa [year].
  Future<List<CalendarEvent>> fetchSeasonActs({required int year}) async {
    final range = seasonActsRange(year);
    final start = range.start;
    final end = range.end;
    const types = {
      EventType.iguala,
      EventType.ensayo,
      EventType.muda,
      EventType.retranqueo,
      EventType.desarma,
    };

    if (_client == null) {
      return mockCalendarEvents
          .where(
            (e) =>
                types.contains(e.type) &&
                !e.date.isBefore(start) &&
                e.date.isBefore(end),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }

    final rows = await _client
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .eq('status', 'published')
        .inFilter(
          'event_type',
          const ['iguala', 'ensayo', 'muda', 'retranqueo', 'desarma'],
        )
        .gte('starts_at', start.toUtc().toIso8601String())
        .lt('starts_at', end.toUtc().toIso8601String())
        .order('starts_at', ascending: true);

    return rows.map(_fromRow).toList();
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
    DateTime? endsAt,
    String? dayLabel,
    String? location,
    String? organizerLabel,
    String? hermandadTopicId,
    String? publisherHandle,
    String? customIconUrl,
    String? coverImageUrl,
    String? admissionLabel,
    List<EventTimeSlot>? timeSlots,
    String? sourceReplyId,
    String? status,
    SeasonPaso paso = SeasonPaso.ambos,
    int? seasonNumber,
    bool withRetranqueo = false,
  }) async {
    if (_client == null) throw CalendarRemoteUnavailableException();

    final hermandadId = hermandadTopicId?.trim();
    final row = await _client!
        .from('calendar_events')
        .insert({
          'title': title,
          'subtitle': subtitle,
          'event_type': type.dbValue,
          'starts_at': startsAt.toUtc().toIso8601String(),
          if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
          'day_label': dayLabel,
          'location': location ?? '',
          'organizer_label': organizerLabel ?? '',
          'hermandad_topic_id':
              (hermandadId == null || hermandadId.isEmpty) ? null : hermandadId,
          'custom_icon_url': customIconUrl ?? '',
          'cover_image_url': coverImageUrl ?? '',
          'admission_label': _admissionOrNull(admissionLabel),
          'time_slots': _slotsPayload(timeSlots),
          'created_by': userId,
          'source_reply_id': ?sourceReplyId,
          'status': ?status,
          'paso': paso.dbValue,
          'season_n': ?seasonNumber,
          'with_retranqueo': withRetranqueo,
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
    DateTime? endsAt,
    bool clearEndsAt = false,
    String? dayLabel,
    String? location,
    String? organizerLabel,
    String? hermandadTopicId,
    bool clearHermandadTopicId = false,
    String? customIconUrl,
    String? coverImageUrl,
    String? admissionLabel,
    List<EventTimeSlot>? timeSlots,
    SeasonPaso paso = SeasonPaso.ambos,
    int? seasonNumber,
    bool withRetranqueo = false,
  }) async {
    if (_client == null) throw CalendarRemoteUnavailableException();

    final hermandadId = hermandadTopicId?.trim();
    final payload = <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'event_type': type.dbValue,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'day_label': dayLabel,
      'location': location ?? '',
      'organizer_label': organizerLabel ?? '',
      'custom_icon_url': customIconUrl ?? '',
      'cover_image_url': coverImageUrl ?? '',
      'admission_label': _admissionOrNull(admissionLabel),
      'time_slots': _slotsPayload(timeSlots),
      'paso': paso.dbValue,
      'season_n': seasonNumber,
      'with_retranqueo': withRetranqueo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (clearHermandadTopicId) {
      payload['hermandad_topic_id'] = null;
    } else if (hermandadId != null) {
      payload['hermandad_topic_id'] =
          hermandadId.isEmpty ? null : hermandadId;
    }
    if (clearEndsAt) {
      payload['ends_at'] = null;
    } else if (endsAt != null) {
      payload['ends_at'] = endsAt.toUtc().toIso8601String();
    }

    final row = await _client!
        .from('calendar_events')
        .update(payload)
        .eq('id', eventId)
        .select('*, profiles!created_by(handle, display_name)')
        .single();

    return _fromRow(row);
  }

  Future<void> setEventLiveForceState({
    required String eventId,
    required EventLiveForceState state,
  }) async {
    if (_client == null) throw CalendarRemoteUnavailableException();
    try {
      await _client!.rpc(
        'admin_set_event_live_force_state',
        params: {
          'p_event_id': eventId,
          'p_force_state': state.dbValue,
        },
      );
    } catch (_) {
      // Fallback si aún no está el RPC: update directo (RLS staff).
      await _client!
          .from('calendar_events')
          .update({
            'live_force_state': state.dbValue,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', eventId);
    }
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

  /// Escudo del tablón oficial si el organizador coincide con una hermandad.
  Future<String?> fetchHermandadIconByOrganizerLabel(
    String organizerLabel,
  ) async {
    final label = organizerLabel.trim();
    if (label.length < 3 || _client == null) return null;
    final key = normalizeOrganizerKey(label);
    if (key.length < 2) return null;

    final logos = await fetchHermandadOrganizerLogos();
    return logos[key]?.logoUrl;
  }

  /// Tablón oficial que corresponde a este organizador, si hay uno.
  Future<String?> findHermandadTopicIdForOrganizer(
    String organizerLabel,
  ) async {
    final match = await findHermandadForOrganizer(organizerLabel);
    return match?.hermandadTopicId?.trim();
  }

  /// Mejor tablón oficial para este nombre de hermandad.
  Future<OrganizerLogo?> findHermandadForOrganizer(
    String organizerLabel,
  ) async {
    final label = organizerLabel.trim();
    if (label.length < 3) return null;

    OrganizerLogo? best;
    var bestScore = 0;

    void consider(OrganizerLogo item, String candidate) {
      final topicId = item.hermandadTopicId?.trim();
      if (topicId == null || topicId.isEmpty) return;
      final score = organizerMatchScore(label, candidate);
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    final logos = await fetchHermandadOrganizerLogos();
    final direct = logos[normalizeOrganizerKey(label)];
    if (direct?.hermandadTopicId?.trim().isNotEmpty == true) return direct;
    for (final item in logos.values) {
      consider(item, item.displayLabel);
      consider(item, item.organizerKey);
    }
    if (bestScore >= 90) return best;

    if (_client != null) {
      try {
        final rows = await _client!
            .from('forum_topics')
            .select('id, title, icon_image_url')
            .eq('forum_id', 'hermandades')
            .eq('status', 'published')
            .limit(400);
        for (final row in rows as List<dynamic>) {
          final map = Map<String, dynamic>.from(row as Map);
          final topicId = (map['id'] as String?)?.trim() ?? '';
          if (topicId.isEmpty) continue;
          final title = (map['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;
          final parsed = parseHermandadTopicTitle(title);
          final name = parsed.hermandadName.trim().isEmpty
              ? title
              : parsed.hermandadName.trim();
          final item = OrganizerLogo(
            organizerKey: normalizeOrganizerKey(name),
            displayLabel: name,
            logoUrl: _nonEmptyUrl(map['icon_image_url'] as String?) ?? '',
            hermandadTopicId: topicId,
          );
          consider(item, name);
          consider(item, title);
        }
      } catch (_) {}
    }
    return bestScore > 0 ? best : null;
  }

  /// Escudos de tablones oficiales indexados por organizador normalizado.
  Future<Map<String, OrganizerLogo>> fetchHermandadOrganizerLogos() async {
    if (_client == null) return const {};

    try {
      final rows = await _client!
          .from('forum_topics')
          .select('id, title, icon_image_url')
          .eq('forum_id', 'hermandades')
          .eq('status', 'published')
          .limit(400);

      final result = <String, OrganizerLogo>{};
      for (final row in rows as List<dynamic>) {
        final map = Map<String, dynamic>.from(row as Map);
        final topicId = (map['id'] as String?)?.trim() ?? '';
        if (topicId.isEmpty) continue;
        final title = (map['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) continue;
        final parsed = parseHermandadTopicTitle(title);
        final name = parsed.hermandadName.trim();
        if (name.length < 3) continue;
        final key = normalizeOrganizerKey(name);
        if (key.length < 2 || result.containsKey(key)) continue;
        result[key] = OrganizerLogo(
          organizerKey: key,
          displayLabel: name,
          logoUrl: _nonEmptyUrl(map['icon_image_url'] as String?) ?? '',
          hermandadTopicId: topicId,
        );
      }
      if (result.isNotEmpty) {
        try {
          final overlayRows = await _client!
              .from('organizer_logos')
              .select('organizer_key, display_label, logo_url')
              .inFilter('organizer_key', result.keys.toList());
          for (final row in overlayRows as List<dynamic>) {
            final overlay = Map<String, dynamic>.from(row as Map);
            final overlayKey =
                (overlay['organizer_key'] as String?)?.trim() ?? '';
            final existing = result[overlayKey];
            if (overlayKey.isEmpty || existing == null) continue;
            final overlayLabel =
                (overlay['display_label'] as String?)?.trim() ?? '';
            final overlayUrl = _nonEmptyUrl(overlay['logo_url'] as String?);
            if (overlayLabel.isEmpty && overlayUrl == null) continue;
            result[overlayKey] = OrganizerLogo(
              organizerKey: existing.organizerKey,
              displayLabel: overlayLabel.isNotEmpty
                  ? overlayLabel
                  : existing.displayLabel,
              logoUrl: overlayUrl ?? existing.logoUrl,
              hermandadTopicId: existing.hermandadTopicId,
            );
          }
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return const {};
    }
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
    String? hermandadTopicId,
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
        hermandadTopicId: hermandadTopicId,
      );
      return;
    }

    final url = logoUrl?.trim();
    final topicId = hermandadTopicId?.trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final resolvedLogo = url != null && url.isNotEmpty
        ? url
        : await _fetchOrganizerLogoUrl(key);

    Future<void> upsertLibraryRow(String organizerKey) async {
      await _client!.from('organizer_logos').upsert({
        'organizer_key': organizerKey,
        'display_label': label,
        'logo_url': resolvedLogo,
        'updated_by': userId,
        'updated_at': nowIso,
      });
    }

    // Los tablones oficiales no tienen fila en organizer_logos: hay que
    // crear/actualizar (upsert), no un update silencioso a 0 filas.
    await upsertLibraryRow(key);

    var boardNameUpdated = false;
    final renamedKey = normalizeOrganizerKey(label);
    if (topicId != null && topicId.isNotEmpty) {
      if (resolvedLogo.isNotEmpty && url != null && url.isNotEmpty) {
        try {
          await _client!.rpc(
            'update_hermandad_board_images',
            params: {
              'p_topic_id': topicId,
              'p_icon_image_url': url,
              'p_set_icon': true,
            },
          );
        } catch (_) {
          // Si el RPC no está, el escudo queda en la biblioteca y se superpone.
        }
      }
      try {
        boardNameUpdated = await _updateHermandadBoardName(
          topicId: topicId,
          hermandadName: label,
        );
      } catch (_) {
        boardNameUpdated = false;
      }
      if (boardNameUpdated &&
          renamedKey.length >= 2 &&
          renamedKey != key) {
        await upsertLibraryRow(renamedKey);
      }
    }

    if (resolvedLogo.isNotEmpty) {
      await _propagateOrganizerLogoToEvents(
        organizerKey: key,
        displayLabel: label,
        logoUrl: resolvedLogo,
        hermandadTopicId: topicId,
        onlyCreatedBy: propagateToAllEvents ? null : userId,
      );
    } else {
      await _propagateOrganizerLabelToEvents(
        organizerKey: key,
        displayLabel: label,
        hermandadTopicId: topicId,
        onlyCreatedBy: propagateToAllEvents ? null : userId,
      );
    }

    if (boardNameUpdated &&
        renamedKey.length >= 2 &&
        renamedKey != key) {
      await _client!
          .from('organizer_logos')
          .delete()
          .eq('organizer_key', key);
    }
  }

  Future<bool> _updateHermandadBoardName({
    required String topicId,
    required String hermandadName,
  }) async {
    final row = await _client!
        .from('forum_topics')
        .select('title')
        .eq('id', topicId)
        .eq('forum_id', 'hermandades')
        .maybeSingle();
    if (row == null) return false;

    final current = (row['title'] as String?)?.trim() ?? '';
    if (current.isEmpty) return false;

    final parsed = parseHermandadTopicTitle(current);
    final next = formatHermandadTopicTitle(
      processionDay: parsed.processionDay,
      hermandadName: hermandadName,
    );
    if (next.length < 3) return false;
    if (next == current) return true;

    await _client!
        .from('forum_topics')
        .update({'title': next})
        .eq('id', topicId)
        .eq('forum_id', 'hermandades');

    final after = await _client!
        .from('forum_topics')
        .select('title')
        .eq('id', topicId)
        .maybeSingle();
    return ((after?['title'] as String?)?.trim() ?? '') == next;
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
    String? hermandadTopicId,
    String? onlyCreatedBy,
  }) async {
    final eventIds = await _matchingOrganizerEventIds(
      organizerKey,
      hermandadTopicId: hermandadTopicId,
      onlyCreatedBy: onlyCreatedBy,
    );
    if (eventIds.isEmpty) return 0;

    final payload = <String, dynamic>{
      'organizer_label': displayLabel,
      'custom_icon_url': logoUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (hermandadTopicId != null && hermandadTopicId.isNotEmpty)
        'hermandad_topic_id': hermandadTopicId,
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
    String? hermandadTopicId,
    String? onlyCreatedBy,
  }) async {
    final eventIds = await _matchingOrganizerEventIds(
      organizerKey,
      hermandadTopicId: hermandadTopicId,
      onlyCreatedBy: onlyCreatedBy,
    );
    if (eventIds.isEmpty) return 0;

    final payload = <String, dynamic>{
      'organizer_label': displayLabel,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (hermandadTopicId != null && hermandadTopicId.isNotEmpty)
        'hermandad_topic_id': hermandadTopicId,
    };

    if (_client == null) return 0;

    for (final eventId in eventIds) {
      await _client!.from('calendar_events').update(payload).eq('id', eventId);
    }
    return eventIds.length;
  }

  Future<List<String>> _matchingOrganizerEventIds(
    String organizerKey, {
    String? hermandadTopicId,
    String? onlyCreatedBy,
  }) async {
    if (_client == null) return const [];

    final topicId = hermandadTopicId?.trim();
    final rows = await _client!
        .from('calendar_events')
        .select('id, organizer_label, created_by, hermandad_topic_id');

    return rows
        .where((row) {
          if (onlyCreatedBy != null &&
              (row['created_by'] as String?) != onlyCreatedBy) {
            return false;
          }
          final linked = (row['hermandad_topic_id'] as String?)?.trim();
          if (topicId != null &&
              topicId.isNotEmpty &&
              linked != null &&
              linked == topicId) {
            return true;
          }
          return normalizeOrganizerKey(
                row['organizer_label'] as String? ?? '',
              ) ==
              organizerKey;
        })
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

    // Preferimos tablones oficiales (con topic id) y completamos con biblioteca.
    final hermandadMap = await fetchHermandadOrganizerLogos();
    final hermandadList = hermandadMap.values.toList()
      ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));

    final q = query.toLowerCase();
    final matchedHermandades = hermandadList
        .where(
          (item) =>
              q.isEmpty ||
              item.displayLabel.toLowerCase().contains(q) ||
              item.organizerKey.contains(q),
        )
        .toList();

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

    final library = rows
        .map(
          (row) => OrganizerLogo(
            organizerKey: row['organizer_key'] as String,
            displayLabel: (row['display_label'] as String?)?.trim() ?? '',
            logoUrl: row['logo_url'] as String? ?? '',
          ),
        )
        .where((item) => item.displayLabel.isNotEmpty)
        .toList();
    final libraryByKey = {
      for (final item in library) item.organizerKey: item,
    };
    final usedLibraryKeys = <String>{};

    OrganizerLogo? overlayFor(OrganizerLogo item) {
      final exact = libraryByKey[item.organizerKey];
      if (exact != null) {
        usedLibraryKeys.add(exact.organizerKey);
        return exact;
      }
      for (final lib in library) {
        if (organizerMatchesHermandadName(lib.displayLabel, item.displayLabel) ||
            organizerMatchesHermandadName(lib.organizerKey, item.displayLabel)) {
          usedLibraryKeys.add(lib.organizerKey);
          return lib;
        }
      }
      return null;
    }

    final mergedHermandades = [
      for (final item in matchedHermandades)
        if (overlayFor(item) case final overlay?)
          OrganizerLogo(
            organizerKey: item.organizerKey,
            displayLabel: item.displayLabel,
            logoUrl: overlay.hasLogo ? overlay.logoUrl : item.logoUrl,
            hermandadTopicId: item.hermandadTopicId,
          )
        else
          item,
    ];
    final libraryOnly = [
      for (final item in library)
        if (!hermandadMap.containsKey(item.organizerKey) &&
            !usedLibraryKeys.contains(item.organizerKey))
          item,
    ];

    return [...mergedHermandades, ...libraryOnly].take(limit).toList();
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
    final hermandadTopicId =
        (row['hermandad_topic_id'] as String?)?.trim();
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
      hermandadTopicId:
          (hermandadTopicId == null || hermandadTopicId.isEmpty)
              ? null
              : hermandadTopicId,
      createdById: row['created_by'] as String?,
      publisherHandle: handle,
      customIconUrl: row['custom_icon_url'] as String?,
      coverImageUrl: _nonEmptyUrl(row['cover_image_url'] as String?),
      status: CalendarEventStatusX.fromDb(row['status'] as String?),
      endsAt: row['ends_at'] != null
          ? DateTime.parse(row['ends_at'] as String).toLocal()
          : null,
      liveForceState: EventLiveForceState.fromDb(
        row['live_force_state'] as String?,
      ),
      viewCount: row['view_count'] as int? ?? 0,
      admissionLabel: _admissionOrNull(row['admission_label'] as String?),
      slots: EventTimeSlot.listFrom(row['time_slots']),
      paso: SeasonPaso.fromDb(row['paso'] as String?),
      seasonNumber: (row['season_n'] as num?)?.toInt(),
      withRetranqueo: row['with_retranqueo'] == true,
    );
  }

  /// Visita a un evento. Devuelve el contador actual (dedupe 1/día).
  Future<int?> incrementEventView(
    String eventId, {
    required String viewerId,
  }) async {
    if (_client == null) return null;
    final result = await _client!.rpc(
      'increment_calendar_event_view',
      params: {'p_event_id': eventId, 'p_viewer_id': viewerId},
    );
    if (result is int) return result;
    if (result is num) return result.toInt();
    return int.tryParse(result?.toString() ?? '');
  }

  Object? _slotsPayload(List<EventTimeSlot>? slots) {
    if (slots == null || slots.isEmpty) return null;
    final hasRange = slots.any((slot) => (slot.end ?? '').isNotEmpty);
    if (slots.length < 2 && !hasRange) return null;
    return slots.map((slot) => slot.toJson()).toList();
  }

  String? _admissionOrNull(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    return text.length > 40 ? text.substring(0, 40) : text;
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
