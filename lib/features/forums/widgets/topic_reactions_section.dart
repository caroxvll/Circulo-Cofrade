import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_provider.dart';
import '../forums_provider.dart';
import 'topic_reactions_bar.dart';

/// Reacciones del tema (cableadas a forum_topic_likes).
class TopicReactionsSection extends ConsumerWidget {
  const TopicReactionsSection({
    super.key,
    required this.topicId,
    this.enabled = true,
  });

  final String topicId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(topicReactionsRealtimeProvider(topicId));
    final counts =
        ref.watch(topicReactionCountsProvider(topicId)).asData?.value ??
            const <String, int>{};
    final userReaction =
        ref.watch(topicUserReactionProvider(topicId)).asData?.value;
    final signedIn = ref.watch(currentUserProvider) != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TopicReactionsBar(
        topicId: topicId,
        reactionCounts: counts,
        userReaction: userReaction,
        enabled: enabled && signedIn,
        onReactionChanged: !enabled
            ? null
            : (reaction) async {
                final user = ref.read(currentUserProvider);
                if (user == null) {
                  if (context.mounted) {
                    context.push(
                      '/login?redirect=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
                    );
                  }
                  return;
                }
                final repo = ref.read(topicReactionsRepositoryProvider);
                await repo.setReaction(
                  userId: user.id,
                  topicId: topicId,
                  reaction: reaction,
                );
                ref.invalidate(topicUserReactionProvider(topicId));
                ref.invalidate(topicReactionCountsProvider(topicId));
              },
      ),
    );
  }
}
