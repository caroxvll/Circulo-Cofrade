import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/hermandad_scheduled_post.dart';
import 'forums_repository.dart';

class HermandadScheduledPostsRepository {
  HermandadScheduledPostsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  static const _select = '*, forum_topics(title)';

  Future<HermandadPendingPosts> fetchMyPending({
    required String authorId,
  }) async {
    if (_client == null) {
      return const HermandadPendingPosts(drafts: [], scheduled: []);
    }

    final rows = await _client!
        .from('hermandad_scheduled_posts')
        .select(_select)
        .eq('author_id', authorId)
        .inFilter('status', ['draft', 'scheduled'])
        .order('updated_at', ascending: false);

    final posts = rows.map(HermandadScheduledPost.fromRow).toList();
    final drafts = posts.where((post) => post.isDraft).toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(
            a.updatedAt ?? DateTime(0),
          ));
    final scheduled = posts.where((post) => post.isScheduled).toList()
      ..sort((a, b) => (a.scheduledAt ?? DateTime(0)).compareTo(
            b.scheduledAt ?? DateTime(0),
          ));

    return HermandadPendingPosts(drafts: drafts, scheduled: scheduled);
  }

  Future<HermandadScheduledPost> createScheduled({
    required String authorId,
    required String authorHandle,
    required String topicId,
    required String content,
    required String officialCategory,
    required DateTime scheduledAt,
    String? imageUrl,
  }) async {
    if (_client == null) throw const ForumsRemoteUnavailableException();

    final row = await _client!
        .from('hermandad_scheduled_posts')
        .insert({
          'author_id': authorId,
          'author_handle': authorHandle,
          'topic_id': topicId,
          'content': content.trim(),
          'official_category': officialCategory,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'status': 'scheduled',
          'image_url': ?imageUrl,
        })
        .select(_select)
        .single();

    return HermandadScheduledPost.fromRow(row);
  }

  Future<HermandadScheduledPost> createDraft({
    required String authorId,
    required String authorHandle,
    required String topicId,
    required String content,
    required String officialCategory,
    String? imageUrl,
  }) async {
    if (_client == null) throw const ForumsRemoteUnavailableException();

    final row = await _client!
        .from('hermandad_scheduled_posts')
        .insert({
          'author_id': authorId,
          'author_handle': authorHandle,
          'topic_id': topicId,
          'content': content.trim(),
          'official_category': officialCategory,
          'status': 'draft',
          'image_url': ?imageUrl,
        })
        .select(_select)
        .single();

    return HermandadScheduledPost.fromRow(row);
  }

  Future<HermandadScheduledPost> updateScheduled({
    required String id,
    required String content,
    required String officialCategory,
    required DateTime scheduledAt,
    String? imageUrl,
  }) async {
    if (_client == null) throw const ForumsRemoteUnavailableException();

    final row = await _client!
        .from('hermandad_scheduled_posts')
        .update({
          'content': content.trim(),
          'official_category': officialCategory,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'status': 'scheduled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'image_url': ?imageUrl,
        })
        .eq('id', id)
        .eq('status', 'scheduled')
        .select(_select)
        .single();

    return HermandadScheduledPost.fromRow(row);
  }

  Future<HermandadScheduledPost> updateDraft({
    required String id,
    required String content,
    required String officialCategory,
    String? imageUrl,
  }) async {
    if (_client == null) throw const ForumsRemoteUnavailableException();

    final row = await _client!
        .from('hermandad_scheduled_posts')
        .update({
          'content': content.trim(),
          'official_category': officialCategory,
          'scheduled_at': null,
          'status': 'draft',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'image_url': ?imageUrl,
        })
        .eq('id', id)
        .eq('status', 'draft')
        .select(_select)
        .single();

    return HermandadScheduledPost.fromRow(row);
  }

  Future<HermandadScheduledPost> scheduleDraft({
    required String id,
    required String content,
    required String officialCategory,
    required DateTime scheduledAt,
    String? imageUrl,
  }) async {
    if (_client == null) throw const ForumsRemoteUnavailableException();

    final row = await _client!
        .from('hermandad_scheduled_posts')
        .update({
          'content': content.trim(),
          'official_category': officialCategory,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'status': 'scheduled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'image_url': ?imageUrl,
        })
        .eq('id', id)
        .eq('status', 'draft')
        .select(_select)
        .single();

    return HermandadScheduledPost.fromRow(row);
  }

  Future<void> cancelPending(String id) async {
    if (_client == null) throw const ForumsRemoteUnavailableException();

    await _client!
        .from('hermandad_scheduled_posts')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .inFilter('status', ['draft', 'scheduled']);
  }

  Future<void> deleteDraft(String id) async {
    if (_client == null) throw const ForumsRemoteUnavailableException();

    await _client!
        .from('hermandad_scheduled_posts')
        .delete()
        .eq('id', id)
        .eq('status', 'draft');
  }

  Future<int> publishDuePosts() async {
    if (_client == null) return 0;

    final result = await _client!.rpc('publish_due_hermandad_scheduled_posts');
    if (result is int) return result;
    if (result is num) return result.toInt();
    return 0;
  }
}

HermandadScheduledPostsRepository createHermandadScheduledPostsRepository() {
  return HermandadScheduledPostsRepository(client: SupabaseBootstrap.client);
}
