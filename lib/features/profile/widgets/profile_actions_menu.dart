import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../../moderation/widgets/report_content_dialog.dart';
import '../../moderation/moderation_provider.dart';

Future<void> showProfileActionsMenu(
  BuildContext context,
  WidgetRef ref, {
  required String profileId,
  required String displayName,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) {
    await context.push(
      '/login?redirect=${Uri.encodeComponent('/perfil/usuario/$profileId')}',
    );
    return;
  }

  if (user.id == profileId) return;

  final isBlocked = await ref.read(profileBlockedProvider(profileId).future);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isBlocked ? Icons.lock_open_outlined : Icons.block_outlined,
                color: AppColors.burgundy,
              ),
              title: Text(isBlocked ? 'Desbloquear' : 'Bloquear'),
              subtitle: Text(
                isBlocked
                    ? 'Volverás a ver su contenido'
                    : 'Solo tú dejarás de ver su contenido. La Junta no recibe aviso.',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _toggleBlock(ref, user.id, profileId, isBlocked);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isBlocked
                            ? 'Usuario desbloqueado'
                            : 'Usuario bloqueado',
                      ),
                    ),
                  );
                  if (!isBlocked) context.pop();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.burgundy),
              title: const Text('Reportar'),
              subtitle: const Text(
                'La Junta revisará el perfil (no es un bloqueo)',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (context.mounted) {
                  await submitContentReport(
                    context: context,
                    ref: ref,
                    reporterId: user.id,
                    targetType: 'profile',
                    targetId: profileId,
                    dialogTitle: 'Reportar perfil',
                  );
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _toggleBlock(
  WidgetRef ref,
  String blockerId,
  String blockedId,
  bool isBlocked,
) async {
  final repo = ref.read(moderationRepositoryProvider);
  if (isBlocked) {
    await repo.unblockUser(blockerId: blockerId, blockedId: blockedId);
  } else {
    await repo.blockUser(blockerId: blockerId, blockedId: blockedId);
  }
  ref.invalidate(blockedUserIdsProvider);
  ref.invalidate(blockedProfilesProvider);
  ref.invalidate(hiddenForumAuthorIdsProvider);
}

