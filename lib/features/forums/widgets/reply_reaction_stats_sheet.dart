import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../topic_detail_typography.dart';
import '../utils/reply_reactions.dart';
import 'reply_reaction_users_sheet.dart';

Future<void> showReplyReactionStatsSheet(
  BuildContext context, {
  required String replyId,
  required Map<String, int> reactionCounts,
}) {
  final normalized = normalizeReactionCounts(reactionCounts);
  final sorted = sortedReactionCounts(normalized);
  final total = totalReactionCount(normalized);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                total == 1 ? '1 reacción' : '$total reacciones',
                style: AppTypography.titleLarge(color: AppColors.burgundy),
              ),
              if (sorted.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (final entry in sorted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        showReplyReactionUsersSheet(
                          context,
                          replyId: replyId,
                          filterEmoji: entry.key,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(entry.key, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reactionLabel(entry.key),
                                style: AppTypography.bodyMedium(),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: TopicDetailTypography.meta(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.textMuted.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  showReplyReactionUsersSheet(context, replyId: replyId);
                },
                child: const Text('Ver quién reaccionó'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
