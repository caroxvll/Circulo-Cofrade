import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/cofradeo_avatar.dart';
import '../auth/auth_provider.dart';
import '../moderation/moderation_provider.dart';

class BlockedAccountsScreen extends ConsumerWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedProfilesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'CUENTAS BLOQUEADAS',
            maxLines: 1,
            softWrap: false,
            style: AppTypography.screenAppBarTitle().copyWith(
              fontSize: 22,
              letterSpacing: 0.35,
            ),
          ),
        ),
        centerTitle: true,
        titleSpacing: 0,
      ),
      body: blockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo cargar la lista.',
              style: AppTypography.bodyMedium(),
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nadie bloqueado',
                    style: AppTypography.displaySmall().copyWith(
                      fontSize: 22,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cuando bloquees a alguien desde su perfil (menú ···), '
                    'aparecerá aquí para que puedas desbloquearlo.',
                    style: AppTypography.bodyMedium(
                      color: AppColors.textMuted,
                    ).copyWith(fontSize: 14.5, height: 1.45),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _BlockedTile(entry: entries[index]);
            },
          );
        },
      ),
    );
  }
}

class _BlockedTile extends ConsumerWidget {
  const _BlockedTile({required this.entry});

  final BlockedProfileEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = entry.profile;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CofradeoAvatar(
            imageUrl: profile.avatarUrl,
            size: 44,
            backgroundColor: AppColors.backgroundElevated,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: AppTypography.titleLarge().copyWith(fontSize: 15),
                ),
                Text(
                  profile.handle,
                  style: AppTypography.labelSmall(color: AppColors.burgundy),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _unblock(context, ref),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }

  Future<void> _unblock(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await ref.read(moderationRepositoryProvider).unblockUser(
          blockerId: user.id,
          blockedId: entry.profile.id,
        );

    ref.invalidate(blockedUserIdsProvider);
    ref.invalidate(blockedProfilesProvider);
    ref.invalidate(hiddenForumAuthorIdsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.profile.displayName} desbloqueado')),
      );
    }
  }
}
