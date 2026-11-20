import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/image_upload_compress.dart';
import '../models/historia.dart';
import '../models/historia_reading_progress.dart';
import 'historia_reading_store.dart';

const historiasHubConfigKey = 'historias_hub';

class HistoriasRepository {
  HistoriasRepository({
    SupabaseClient? client,
    HistoriaReadingStore? readingStore,
  })  : _client = client,
        _readingStore = readingStore ?? HistoriaReadingStore();

  final SupabaseClient? _client;
  final HistoriaReadingStore _readingStore;

  static const _coversBucket = 'historia-covers';
  static const shelfPageSize = 24;
  static const _historiaSelect =
      'id, author_id, title, excerpt, kind, cover_image_url, pages, status, '
      'scheduled_at, review_note, comment_count, created_at, '
      'profiles!author_id (handle, display_name, avatar_url)';
  static const _historiaListSelect =
      'id, author_id, title, excerpt, kind, cover_image_url, status, '
      'scheduled_at, review_note, comment_count, created_at, '
      'profiles!author_id (handle, display_name, avatar_url)';
  static const _commentSelect =
      'id, historia_id, user_id, body, created_at, '
      'profiles!user_id (handle, display_name, avatar_url)';
  static const _maxPages = 30;
  static const _minTitle = 3;
  static const _maxTitle = 80;
  static const _maxExcerpt = 280;
  static const _maxPageChars = 3500;

  bool get isAvailable => _client != null;

  Future<void> publishDue() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc('publish_due_historias');
    } catch (_) {}
  }

  Future<bool> isHubEnabled() async {
    final client = _client;
    if (client == null) return false;
    try {
      final row = await client
          .from('app_config')
          .select('value')
          .eq('key', historiasHubConfigKey)
          .maybeSingle();
      return (row?['value'] as String?)?.trim() == 'on';
    } catch (_) {
      return false;
    }
  }

  Future<List<Historia>> fetchPublished({
    int offset = 0,
    int limit = shelfPageSize,
    HistoriaKind? kind,
    Iterable<String>? authorIds,
  }) async {
    final client = _client;
    if (client == null) return [];
    if (authorIds != null && authorIds.isEmpty) return [];
    await publishDue();
    var query = client
        .from('historias')
        .select(_historiaListSelect)
        .eq('status', 'published');
    if (kind != null) {
      query = query.eq('kind', kind.dbValue);
    }
    if (authorIds != null) {
      query = query.inFilter('author_id', authorIds.toList());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(_fromRow).toList();
  }

  Future<List<Historia>> fetchAllForStaff() async {
    final client = _client;
    if (client == null) return [];
    await publishDue();
    final rows = await client
        .from('historias')
        .select(_historiaListSelect)
        .order('created_at', ascending: false)
        .range(0, 99);
    return rows.map(_fromRow).toList();
  }

  Future<Historia?> fetchById(String id) async {
    final client = _client;
    if (client == null) return null;
    await publishDue();
    final row = await client
        .from('historias')
        .select(_historiaSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(row);
  }

  Future<List<Historia>> fetchPublishedByAuthor(String authorId) async {
    final client = _client;
    if (client == null) return [];
    await publishDue();
    final rows = await client
        .from('historias')
        .select(_historiaListSelect)
        .eq('status', 'published')
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(0, 79);
    return rows.map(_fromRow).toList();
  }

  Future<List<Historia>> fetchMine() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return [];
    await publishDue();
    final rows = await client
        .from('historias')
        .select(_historiaListSelect)
        .eq('author_id', userId)
        .order('updated_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  Future<Historia> create({
    required String title,
    required String excerpt,
    required List<HistoriaPage> pages,
    HistoriaKind kind = HistoriaKind.articulo,
    String status = 'published',
    String? coverImageUrl,
    DateTime? scheduledAt,
  }) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw const HistoriasUnavailableException();

    final payload = _payload(
      title: title,
      excerpt: excerpt,
      pages: pages,
      kind: kind,
      status: status,
      coverImageUrl: coverImageUrl,
      scheduledAt: scheduledAt,
    );

    final row = await client
        .from('historias')
        .insert({
          'author_id': userId,
          ...payload,
        })
        .select(_historiaSelect)
        .single();

    return _fromRow(row);
  }

  Future<Historia> updateHistoria({
    required String historiaId,
    required String title,
    required String excerpt,
    required List<HistoriaPage> pages,
    HistoriaKind kind = HistoriaKind.articulo,
    String? status,
    String? coverImageUrl,
    DateTime? scheduledAt,
  }) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();
    final payload = _payload(
      title: title,
      excerpt: excerpt,
      pages: pages,
      kind: kind,
      status: status,
      coverImageUrl: coverImageUrl,
      scheduledAt: scheduledAt,
    );
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final row = await client
        .from('historias')
        .update(payload)
        .eq('id', historiaId)
        .select(_historiaSelect)
        .single();
    return _fromRow(row);
  }

  Future<String> uploadCover({
    required String authorId,
    required String historiaId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();

    final prepared = await prepareImageUploadAsync(
      rawBytes: bytes,
      extension: extension,
      contentType: contentType,
      maxBytes: ImageUploadLimits.pillarCoverMaxBytes,
      maxSide: ImageUploadLimits.pillarCoverMaxSide,
    );

    final path = '$authorId/$historiaId.${prepared.extension}';
    await client.storage.from(_coversBucket).uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: prepared.contentType,
          ),
        );

    final publicUrl = client.storage.from(_coversBucket).getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadPageImage({
    required String authorId,
    required String historiaId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();

    final prepared = await prepareImageUploadAsync(
      rawBytes: bytes,
      extension: extension,
      contentType: contentType,
      maxBytes: ImageUploadLimits.pillarCoverMaxBytes,
      maxSide: ImageUploadLimits.pillarCoverMaxSide,
    );

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$authorId/$historiaId/p$stamp.${prepared.extension}';
    await client.storage.from(_coversBucket).uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: prepared.contentType,
          ),
        );

    final publicUrl = client.storage.from(_coversBucket).getPublicUrl(path);
    return '$publicUrl?v=$stamp';
  }

  Future<void> setCoverUrl({
    required String historiaId,
    required String coverImageUrl,
  }) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();
    await client.from('historias').update({
      'cover_image_url': coverImageUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', historiaId);
  }

  Future<void> setStatus({
    required String historiaId,
    required String status,
    String? reviewNote,
    bool clearReviewNote = false,
  }) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (clearReviewNote) {
      payload['review_note'] = null;
    } else if (reviewNote != null) {
      payload['review_note'] = reviewNote.trim();
    }
    await client.from('historias').update(payload).eq('id', historiaId);
  }

  Future<void> deleteHistoria(String historiaId) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();
    await client.from('historias').delete().eq('id', historiaId);
  }

  static const commentsPageSize = 30;

  Future<List<HistoriaComment>> fetchComments(
    String historiaId, {
    int offset = 0,
    int limit = commentsPageSize,
  }) async {
    final client = _client;
    if (client == null) return [];
    final rows = await client
        .from('historia_comments')
        .select(_commentSelect)
        .eq('historia_id', historiaId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(_commentFromRow).toList();
  }

  Future<HistoriaComment> addComment({
    required String historiaId,
    required String body,
  }) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw const HistoriasUnavailableException();

    final clean = body.trim();
    if (clean.isEmpty || clean.length > 500) {
      throw const HistoriasValidationException(
        'El comentario debe tener entre 1 y 500 caracteres.',
      );
    }

    final row = await client
        .from('historia_comments')
        .insert({
          'historia_id': historiaId,
          'user_id': userId,
          'body': clean,
        })
        .select(_commentSelect)
        .single();
    return _commentFromRow(row);
  }

  Future<void> deleteComment(String commentId) async {
    final client = _client;
    if (client == null) throw const HistoriasUnavailableException();
    await client.from('historia_comments').delete().eq('id', commentId);
  }

  String? get _userId => _client?.auth.currentUser?.id;

  Future<int> loadReadingPage(String historiaId) async {
    final userId = _userId;
    if (userId == null) return 0;
    final local = await _readingStore.load(userId, historiaId);
    try {
      final client = _client;
      if (client != null) {
        final row = await client
            .from('historia_reading_progress')
            .select('page, page_count, updated_at')
            .eq('user_id', userId)
            .eq('historia_id', historiaId)
            .maybeSingle();
        final remote = HistoriaReadingMark.tryParse(historiaId, {
          ...?row,
          'pageCount': row?['page_count'],
        });
        if (remote != null &&
            (local == null || !remote.updatedAt.isBefore(local.updatedAt))) {
          await _readingStore.save(userId, remote);
          return remote.page;
        }
      }
    } catch (_) {}
    return local?.page ?? 0;
  }

  Future<void> saveReadingProgress({
    required String historiaId,
    required int page,
    required int pageCount,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final mark = HistoriaReadingMark(
      historiaId: historiaId,
      page: page,
      pageCount: pageCount < 1 ? 1 : pageCount,
      updatedAt: DateTime.now(),
    );
    await _readingStore.save(userId, mark);
    final client = _client;
    if (client == null) return;
    try {
      if (!mark.isInProgress) {
        await client
            .from('historia_reading_progress')
            .delete()
            .eq('user_id', userId)
            .eq('historia_id', historiaId);
        return;
      }
      await client.from('historia_reading_progress').upsert({
        'user_id': userId,
        'historia_id': historiaId,
        'page': mark.page,
        'page_count': mark.pageCount,
        'updated_at': mark.updatedAt.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<List<HistoriaContinueItem>> fetchContinueReading({int limit = 12}) async {
    final userId = _userId;
    if (userId == null) return const [];
    final local = await _readingStore.loadAll(userId);
    final byId = <String, HistoriaReadingMark>{
      for (final mark in local.values)
        if (mark.isInProgress) mark.historiaId: mark,
    };
    try {
      final client = _client;
      if (client != null) {
        final rows = await client
            .from('historia_reading_progress')
            .select('page, page_count, updated_at, historia_id')
            .eq('user_id', userId)
            .order('updated_at', ascending: false)
            .limit(40);
        for (final row in rows) {
          final historiaId = row['historia_id'] as String?;
          if (historiaId == null) continue;
          final remote = HistoriaReadingMark.tryParse(historiaId, {
            ...row,
            'pageCount': row['page_count'],
          });
          if (remote == null) continue;
          final localMark = byId[historiaId];
          if (localMark == null || !remote.updatedAt.isBefore(localMark.updatedAt)) {
            byId[historiaId] = remote;
            await _readingStore.save(userId, remote);
          }
        }
      }
    } catch (_) {}

    final inProgress = byId.values.where((m) => m.isInProgress).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (inProgress.isEmpty) return const [];
    final sliced = inProgress.take(limit).toList();
    final historias = await fetchByIds(sliced.map((m) => m.historiaId));
    final map = {for (final item in historias) item.id: item};
    return [
      for (final mark in sliced)
        if (map[mark.historiaId] != null)
          HistoriaContinueItem(historia: map[mark.historiaId]!, mark: mark),
    ];
  }

  Future<List<Historia>> fetchByIds(Iterable<String> ids) async {
    final client = _client;
    final list = ids.toSet().toList();
    if (client == null || list.isEmpty) return const [];
    final rows = await client
        .from('historias')
        .select(_historiaListSelect)
        .inFilter('id', list)
        .eq('status', 'published');
    return rows.map(_fromRow).toList();
  }

  Map<String, dynamic> _payload({
    required String title,
    required String excerpt,
    required List<HistoriaPage> pages,
    required HistoriaKind kind,
    String? status,
    String? coverImageUrl,
    DateTime? scheduledAt,
  }) {
    final cleanTitle = title.trim();
    final cleanExcerpt = excerpt.trim();
    final cleanPages = pages.where((p) => !p.isEmpty).toList();

    if (cleanTitle.length < _minTitle || cleanTitle.length > _maxTitle) {
      throw HistoriasValidationException(
        'El título debe tener entre $_minTitle y $_maxTitle caracteres.',
      );
    }
    if (cleanExcerpt.length > _maxExcerpt) {
      throw const HistoriasValidationException(
        'La entradilla no puede pasar de 280 caracteres.',
      );
    }
    if (cleanPages.isEmpty) {
      throw const HistoriasValidationException(
        'Añade al menos una página con texto o foto.',
      );
    }
    if (cleanPages.length > _maxPages) {
      throw HistoriasValidationException(
        'Como máximo $_maxPages páginas.',
      );
    }
    if (cleanPages.any((p) => p.body.length > _maxPageChars)) {
      throw const HistoriasValidationException(
        'Alguna página pasa de 3500 caracteres.',
      );
    }

    final payload = <String, dynamic>{
      'title': cleanTitle,
      'excerpt': cleanExcerpt,
      'kind': kind.dbValue,
      'pages': cleanPages.map((p) => p.toJson()).toList(),
    };
    if (status != null) payload['status'] = status;
    if (status == 'pending_review' || status == 'published') {
      payload['review_note'] = null;
    }
    if (status == 'scheduled') {
      final when = scheduledAt;
      if (when == null ||
          !when.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        throw const HistoriasValidationException(
          'Elige un momento al menos 5 minutos más adelante.',
        );
      }
      payload['scheduled_at'] = when.toUtc().toIso8601String();
    } else if (status != null) {
      payload['scheduled_at'] = null;
    }
    final cover = coverImageUrl?.trim() ?? '';
    if (cover.isNotEmpty) payload['cover_image_url'] = cover;
    return payload;
  }

  Historia _fromRow(Map<String, dynamic> row) {
    final profile = _embedProfile(row['profiles']);
    return Historia(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorHandle: profile.handle,
      authorDisplayName: profile.displayName,
      authorAvatarUrl: profile.avatarUrl,
      title: row['title'] as String? ?? '',
      excerpt: row['excerpt'] as String? ?? '',
      kind: HistoriaKind.fromDb(row['kind'] as String?),
      coverImageUrl: row['cover_image_url'] as String?,
      pages: HistoriaPage.parseList(row['pages']),
      status: row['status'] as String? ?? 'published',
      scheduledAt: row['scheduled_at'] == null
          ? null
          : DateTime.parse(row['scheduled_at'] as String).toLocal(),
      reviewNote: row['review_note'] as String?,
      commentCount: row['comment_count'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  HistoriaComment _commentFromRow(Map<String, dynamic> row) {
    final profile = _embedProfile(row['profiles']);
    return HistoriaComment(
      id: row['id'] as String,
      historiaId: row['historia_id'] as String,
      userId: row['user_id'] as String,
      userHandle: profile.handle,
      userDisplayName: profile.displayName,
      userAvatarUrl: profile.avatarUrl,
      body: row['body'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  ({String handle, String displayName, String? avatarUrl}) _embedProfile(
    Object? raw,
  ) {
    if (raw is Map) {
      final handleRaw = raw['handle'] as String? ?? '';
      final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
      return (
        handle: handle.isEmpty ? '@cofrade' : handle,
        displayName: raw['display_name'] as String? ?? handle,
        avatarUrl: raw['avatar_url'] as String?,
      );
    }
    return (handle: '@cofrade', displayName: 'Cofrade', avatarUrl: null);
  }
}

class HistoriasUnavailableException implements Exception {
  const HistoriasUnavailableException();
}

class HistoriasValidationException implements Exception {
  const HistoriasValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}
