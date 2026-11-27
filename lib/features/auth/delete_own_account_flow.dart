import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/cofrade_confirm_dialog.dart';
import '../profile/profile_provider.dart';
import 'auth_error_messages.dart';
import 'auth_provider.dart';

Future<void> confirmAndDeleteOwnAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  final first = await showCofradeConfirmDialog(
    context: context,
    title: 'Eliminar cuenta',
    message:
        'Se borrará tu cuenta y todo rastro en Círculo Cofrade: perfil, '
        'textos, fotos, eventos, avisos y archivos. No se puede deshacer.',
    cancelLabel: 'Cancelar',
    confirmLabel: 'Eliminar',
    destructive: true,
  );
  if (first != true || !context.mounted) return;

  final second = await showCofradeConfirmDialog(
    context: context,
    title: 'Confirmar borrado',
    message: '¿Seguro que quieres eliminar tu cuenta de Círculo Cofrade?',
    cancelLabel: 'Cancelar',
    confirmLabel: 'Sí, eliminar',
    destructive: true,
  );
  if (second != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.burgundy),
    ),
  );

  try {
    await ref.read(authRepositoryProvider).deleteOwnAccount();
    ref.invalidate(currentUserProfileProvider);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta eliminada')),
    );
  } on AuthException catch (error) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyAuthErrorMessage(error))),
    );
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo eliminar la cuenta. Inténtalo de nuevo.'),
      ),
    );
  }
}
