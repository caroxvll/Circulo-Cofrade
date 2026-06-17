import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_branding.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../admin/admin_provider.dart';
import '../../auth/auth_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../profile_provider.dart';

Future<void> showOwnProfileMenu(BuildContext context, WidgetRef ref) async {
  final isStaff = ref.read(isStaffProvider);

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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Tu cuenta',
                style: AppTypography.titleLarge().copyWith(fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.burgundy),
              title: const Text('Editar perfil'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/perfil/editar');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications_none_outlined,
                color: AppColors.burgundy,
              ),
              title: const Text('Avisos'),
              subtitle: const Text('Preferencias de notificaciones'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/perfil/notificaciones');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined, color: AppColors.burgundy),
              title: const Text('Cuentas bloqueadas'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/perfil/bloqueados');
              },
            ),
            if (isStaff)
              ListTile(
                leading: const Icon(Icons.gavel_outlined, color: AppColors.burgundy),
                title: const Text('Junta de Gobierno'),
                subtitle: const Text('Moderación y reportes'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/perfil/junta');
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.accentRed),
              title: Text(
                'Cerrar sesión',
                style: AppTypography.bodyLarge(color: AppColors.accentRed),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: Text(AppBranding.logoutConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text(
                          'Salir',
                          style: AppTypography.bodyMedium(
                            color: AppColors.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;

                ScaffoldMessenger.of(context).clearSnackBars();
                await ref.read(authRepositoryProvider).signOut();
                ref.invalidate(currentUserProfileProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión cerrada'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
