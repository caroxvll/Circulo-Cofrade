import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../models/sponsored_ad.dart';

class AdsRemoteUnavailableException implements Exception {}

class AdAssetTooLargeException implements Exception {}

String normalizeAdTargetUrl(String raw) {
  var trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  if (trimmed.startsWith('s://')) {
    trimmed = 'https${trimmed.substring(1)}';
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  return 'https://$trimmed';
}

String adSaveErrorMessage(Object error) {
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (error.code == '42501' || message.contains('row-level security')) {
      return 'No tienes permiso para gestionar anuncios. Revisa que tu perfil sea admin en Supabase.';
    }
    if (message.contains('does not exist') || error.code == '42P01') {
      return 'Falta configurar la base de datos de anuncios. Ejecuta supabase/ads.sql.';
    }
    if (message.contains('violates check constraint')) {
      return 'Algún dato no cumple los límites (título, descripción, prioridad…).';
    }
    return error.message;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('bucket not found')) {
    return 'Falta el almacén de imágenes de anuncios. Ejecuta supabase/ads.sql en Supabase.';
  }
  if (text.contains('row-level security') || text.contains('42501')) {
    return 'No tienes permiso para subir la imagen del anuncio.';
  }
  if (text.contains('payload too large') || text.contains('413')) {
    return 'La imagen no puede superar 4 MB.';
  }

  return 'No se pudo guardar el anuncio. Inténtalo de nuevo.';
}

class AdsRepository {
  AdsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static const _adAssetsBucket = 'ad-assets';
  static const _maxAdAssetBytes = 4 * 1024 * 1024;

  bool get isAvailable => _client != null;

  Future<SponsoredAd?> fetchAd(
    AdPlacement placement, {
    String? forumId,
    String? topicId,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final rows = await client.rpc<List<dynamic>>(
        'get_ad_for_placement',
        params: {
          'p_placement': placement.value,
          'p_forum_id': forumId,
          'p_topic_id': topicId,
        },
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      if (row is! Map<String, dynamic>) return null;
      return SponsoredAd.fromRow(row);
    } on PostgrestException {
      return null;
    }
  }

  Future<List<SponsoredAd>> fetchAdminAds() async {
    final client = _client;
    if (client == null) return [];

    final rows = await client
        .from('ads')
        .select()
        .order('placement', ascending: true)
        .order('priority', ascending: false)
        .order('created_at', ascending: false);

    return rows.map(SponsoredAd.fromRow).toList();
  }

  Future<void> saveAd({
    String? id,
    required String title,
    required String description,
    required String sponsorName,
    required String buttonText,
    required String targetUrl,
    required AdPlacement placement,
    String? imageUrl,
    String? sponsorLogoUrl,
    String? calendarEventId,
    String? forumId,
    String? topicId,
    required int priority,
    required int maxImpressions,
    required bool active,
  }) async {
    final client = _client;
    if (client == null) return;

    final payload = {
      'title': title,
      'description': description,
      'sponsor_name': sponsorName,
      'button_text': buttonText,
      'target_url': targetUrl,
      'placement': placement.value,
      'image_url': _emptyToNull(imageUrl),
      'sponsor_logo_url': _emptyToNull(sponsorLogoUrl),
      'calendar_event_id': _emptyToNull(calendarEventId),
      'forum_id': _emptyToNull(forumId),
      'topic_id': _emptyToNull(topicId),
      'priority': priority,
      'max_impressions': maxImpressions,
      'active': active,
    };

    if (id == null) {
      await client.from('ads').insert(payload);
    } else {
      await client.from('ads').update(payload).eq('id', id);
    }
  }

  Future<void> setAdActive({required String adId, required bool active}) async {
    final client = _client;
    if (client == null) return;
    await client.from('ads').update({'active': active}).eq('id', adId);
  }

  Future<void> deleteAd({required String adId}) async {
    final client = _client;
    if (client == null) return;
    await client.from('ads').delete().eq('id', adId);
  }

  Future<String> uploadAdAsset({
    required Uint8List bytes,
    required String extension,
    required String contentType,
    required String folder,
  }) async {
    final client = _client;
    if (client == null) throw AdsRemoteUnavailableException();
    if (bytes.length > _maxAdAssetBytes) throw AdAssetTooLargeException();

    final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    final path = '$safeFolder/$fileName';

    await client.storage
        .from(_adAssetsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    return client.storage.from(_adAssetsBucket).getPublicUrl(path);
  }

  Future<void> registerImpression({
    required String adId,
    required String viewerId,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'register_ad_impression',
      params: {'p_ad_id': adId, 'p_viewer_id': viewerId},
    );
  }

  Future<void> registerClick({
    required String adId,
    required String viewerId,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'register_ad_click',
      params: {'p_ad_id': adId, 'p_viewer_id': viewerId},
    );
  }

  /// Informe de impresiones / clics por anuncio.
  /// [from] inclusive, [to] exclusive. Ambos null = todo el tiempo.
  Future<List<AdStatisticsRow>> fetchAdStatistics({
    DateTime? from,
    DateTime? to,
  }) async {
    final client = _client;
    if (client == null) return [];

    final rows = await client.rpc(
      'get_ad_statistics',
      params: {
        'p_from': from?.toUtc().toIso8601String(),
        'p_to': to?.toUtc().toIso8601String(),
      },
    );

    return (rows as List)
        .map(
          (row) => AdStatisticsRow.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}

class AdStatisticsRow {
  const AdStatisticsRow({
    required this.id,
    required this.title,
    required this.sponsorName,
    required this.placement,
    required this.trackedImpressions,
    required this.clicks,
    required this.ctr,
    required this.currentImpressions,
  });

  final String id;
  final String title;
  final String sponsorName;
  final String placement;
  final int trackedImpressions;
  final int clicks;
  final double ctr;
  final int currentImpressions;

  factory AdStatisticsRow.fromRow(Map<String, dynamic> row) {
    return AdStatisticsRow(
      id: row['id'].toString(),
      title: row['title'] as String? ?? '',
      sponsorName: row['sponsor_name'] as String? ?? '',
      placement: row['placement'] as String? ?? '',
      trackedImpressions: row['tracked_impressions'] as int? ?? 0,
      clicks: row['clicks'] as int? ?? 0,
      ctr: (row['ctr'] as num?)?.toDouble() ?? 0,
      currentImpressions: row['current_impressions'] as int? ?? 0,
    );
  }

  String get displayName {
    final sponsor = sponsorName.trim();
    if (sponsor.isNotEmpty) return sponsor;
    return title.trim().isEmpty ? 'Sin nombre' : title.trim();
  }
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

AdsRepository createAdsRepository() {
  return AdsRepository(client: SupabaseBootstrap.client);
}
