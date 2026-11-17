import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../models/topic_poll.dart';

class TopicPollsRepository {
  TopicPollsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<TopicPoll?> fetchPollForTopic(String topicId) async {
    final client = _client;
    if (client == null) return null;

    final pollRow = await client
        .from('topic_polls')
        .select('id, topic_id, question, closed_at')
        .eq('topic_id', topicId)
        .maybeSingle();

    if (pollRow == null) return null;

    final pollId = pollRow['id'].toString();

    final optionRows = await client
        .from('topic_poll_options')
        .select('id, label, sort_order')
        .eq('poll_id', pollId)
        .order('sort_order');

    final voteRows = await client
        .from('topic_poll_votes')
        .select('option_id, user_id')
        .eq('poll_id', pollId);

    final counts = <String, int>{};
    String? myOptionId;
    final uid = client.auth.currentUser?.id;

    for (final row in voteRows) {
      final optionId = row['option_id'].toString();
      counts[optionId] = (counts[optionId] ?? 0) + 1;
      if (uid != null && row['user_id']?.toString() == uid) {
        myOptionId = optionId;
      }
    }

    final options = optionRows.map((row) {
      final id = row['id'].toString();
      return TopicPollOption(
        id: id,
        label: (row['label'] as String?)?.trim() ?? '',
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        voteCount: counts[id] ?? 0,
      );
    }).toList();

    return TopicPoll(
      id: pollId,
      topicId: pollRow['topic_id'].toString(),
      question: (pollRow['question'] as String?)?.trim() ?? '',
      options: options,
      myOptionId: myOptionId,
      closedAt: pollRow['closed_at'] != null
          ? DateTime.tryParse(pollRow['closed_at'].toString())
          : null,
    );
  }

  Future<void> createPoll({
    required String topicId,
    required String question,
    required List<String> options,
  }) async {
    final client = _client;
    if (client == null) throw const TopicPollsUnavailableException();

    final cleaned = options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();

    await client.rpc(
      'create_topic_poll',
      params: {
        'p_topic_id': topicId,
        'p_question': question.trim(),
        'p_options': cleaned,
      },
    );
  }

  Future<void> vote(String optionId) async {
    final client = _client;
    if (client == null) throw const TopicPollsUnavailableException();

    await client.rpc(
      'vote_topic_poll',
      params: {'p_option_id': optionId},
    );
  }
}

class TopicPollsUnavailableException implements Exception {
  const TopicPollsUnavailableException();
}

TopicPollsRepository createTopicPollsRepository() {
  return TopicPollsRepository(client: SupabaseBootstrap.client);
}
