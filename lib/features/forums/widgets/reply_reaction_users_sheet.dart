import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../data/reply_likes_repository.dart';
import '../forums_provider.dart';
import '../utils/reply_reactions.dart';

final replyReactionUsersProvider =
    FutureProvider.autoDispose.family<List<ReplyReactionUser>, String>((
  ref,
  replyId,
) async {
  final repo = ref.watch(replyLikesRepositoryProvider);
  if (!repo.isAvailable) return [];
  return repo.fetchReactionUsers(replyId: replyId);
});

Future<void> showReplyReactionUsersSheet(
  BuildContext context, {
  required String replyId,
  String? filterEmoji,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _ReplyReactionUsersSheet(
      replyId: replyId,
      filterEmoji: filterEmoji,
    ),
  );
}

class _ReplyReactionUsersSheet extends ConsumerWidget {
  const _ReplyReactionUsersSheet({
    required this.replyId,
    this.filterEmoji,
  });

  final String replyId;
  final String? filterEmoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(replyReactionUsersProvider(replyId));
    final filterLabel = filterEmoji != null ? reactionLabel(filterEmoji) : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                filterEmoji != null
                    ? '$filterEmoji $filterLabel'
                    : 'Reacciones',
                style: AppTypography.titleLarge(
                  color: AppColors.burgundy,
                ),
              ),
            ),
            usersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la lista. ¿Ejecutaste reply_reaction_notify.sql?',
                  style: AppTypography.bodyMedium(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              data: (users) {
                final filtered = filterEmoji == null
                    ? users
                    : users
                        .where(
                          (u) => reactionsEqual(u.reaction, filterEmoji),
                        )
                        .toList();
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Text(
                      'Nadie ha reaccionado todavía.',
                      style: AppTypography.bodyMedium(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: CofradeoAvatar(
                          imageUrl: user.avatarUrl,
                          size: 40,
                        ),
                        title: Text(
                          user.displayName,
                          style: AppTypography.bodyMedium().copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          user.displayHandle,
                          style: AppTypography.labelSmall(
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: Text(
                          replyReactionDisplay(user.reaction),
                          style: const TextStyle(fontSize: 20),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/perfil/usuario/${user.userId}');
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
