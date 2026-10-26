import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../forums_provider.dart';
import '../models/topic_poll.dart';
import '../utils/forum_navigation.dart';

class TopicPollCard extends ConsumerStatefulWidget {
  const TopicPollCard({
    super.key,
    required this.forumId,
    required this.topicId,
  });

  final String forumId;
  final String topicId;

  @override
  ConsumerState<TopicPollCard> createState() => _TopicPollCardState();
}

class _TopicPollCardState extends ConsumerState<TopicPollCard> {
  String? _votingOptionId;

  Future<void> _vote(TopicPoll poll, String optionId) async {
    final isAuth = ref.read(isAuthenticatedProvider);
    if (!isAuth) {
      final redirect = forumTopicLocation(widget.forumId, widget.topicId);
      if (mounted) {
        await context.push('/login?redirect=${Uri.encodeComponent(redirect)}');
      }
      return;
    }
    if (!await ensureEmailVerifiedForEngage(context, ref)) return;

    setState(() => _votingOptionId = optionId);
    try {
      await ref.read(topicPollsRepositoryProvider).vote(optionId);
      ref.invalidate(topicPollProvider(widget.topicId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar el voto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _votingOptionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pollAsync = ref.watch(topicPollProvider(widget.topicId));

    return pollAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (poll) {
        if (poll == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _PollBody(
            poll: poll,
            votingOptionId: _votingOptionId,
            onVote: (optionId) => _vote(poll, optionId),
          ),
        );
      },
    );
  }
}

class _PollBody extends StatelessWidget {
  const _PollBody({
    required this.poll,
    required this.votingOptionId,
    required this.onVote,
  });

  final TopicPoll poll;
  final String? votingOptionId;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final showResults = poll.hasVoted || poll.isClosed;
    final total = poll.totalVotes;
    final busy = votingOptionId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ENCUESTA',
            style: AppTypography.labelSmall(
              color: AppColors.textMuted,
            ).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            poll.question,
            style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final option in poll.options) ...[
            if (showResults)
              _ResultRow(
                option: option,
                total: total,
                selected: option.id == poll.myOptionId,
              )
            else
              _VoteButton(
                label: option.label,
                enabled: !busy && !poll.isClosed,
                loading: votingOptionId == option.id,
                onTap: () => onVote(option.id),
              ),
            const SizedBox(height: 8),
          ],
          Text(
            total == 0
                ? (poll.isClosed ? 'Encuesta cerrada · sin votos' : 'Sé el primero en votar')
                : '$total ${total == 1 ? 'voto' : 'votos'}${poll.isClosed ? ' · cerrada' : ''}',
            style: AppTypography.labelSmall(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.option,
    required this.total,
    required this.selected,
  });

  final TopicPollOption option;
  final int total;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : option.voteCount / total;
    final pct = (ratio * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? AppColors.burgundy.withValues(alpha: 0.45)
              : AppColors.border,
        ),
        color: selected
            ? AppColors.burgundy.withValues(alpha: 0.06)
            : AppColors.backgroundElevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                      .copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: AppTypography.labelSmall(
                  color: selected ? AppColors.burgundyDark : AppColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.border.withValues(alpha: 0.55),
              color: selected ? AppColors.burgundy : AppColors.goldDark,
            ),
          ),
        ],
      ),
    );
  }
}
