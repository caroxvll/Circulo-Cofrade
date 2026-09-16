import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';
import '../../admin/admin_provider.dart';
import '../../moderation/moderation_provider.dart';

class StaffProfileActionsBar extends ConsumerStatefulWidget {
  const StaffProfileActionsBar({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<StaffProfileActionsBar> createState() =>
      _StaffProfileActionsBarState();
}

class _StaffProfileActionsBarState
    extends ConsumerState<StaffProfileActionsBar> {
  var _busy = false;

  Future<void> _setVerified(bool verified) async {
    final profile = widget.profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          verified
              ? '¿Verificar ${profile.handle}?'
              : '¿Quitar verificación a ${profile.handle}?',
        ),
        content: Text(
          verified
              ? 'Se mostrará una insignia para indicar que esta cuenta ha sido verificada por Cofradeo.'
              : 'La cuenta dejará de aparecer como verificada en perfiles, búsqueda y foros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
            ),
            child: Text(verified ? 'Verificar' : 'Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setProfileVerified(profileId: profile.id, verified: verified);
      invalidateAuthorVisibility(ref, profileId: profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              verified
                  ? '${profile.handle} verificada'
                  : 'Verificación retirada a ${profile.handle}',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar la verificación. ¿Ejecutaste profile_verification.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _suspend() async {
    final profile = widget.profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Suspender ${profile.handle}?'),
        content: const Text(
          'La cuenta no podrá publicar ni responder en foros. '
          'El usuario verá un aviso en su perfil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
            ),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .suspendProfile(
            profileId: profile.id,
            reason: 'Suspensión manual desde perfil',
          );
      invalidateAuthorVisibility(ref, profileId: profile.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${profile.handle} suspendida')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo suspender la cuenta')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reactivate() async {
    final profile = widget.profile;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).unsuspendProfile(profile.id);
      invalidateAuthorVisibility(ref, profileId: profile.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${profile.handle} reactivada')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reactivar la cuenta')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isAdminProvider) || widget.profile.isAdmin) {
      return const SizedBox.shrink();
    }

    final profile = widget.profile;
    final isAdmin = ref.watch(isAdminProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Acciones de la Junta',
          style: AppTypography.labelSmall(color: AppColors.burgundy),
        ),
        const SizedBox(height: 8),
        if (isAdmin) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _setVerified(!profile.isVerified),
            icon: Icon(
              profile.isVerified
                  ? Icons.remove_circle_outline
                  : Icons.verified_outlined,
              size: 18,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: const BorderSide(color: AppColors.burgundy),
            ),
            label: Text(
              profile.isVerified ? 'Quitar verificación' : 'Verificar cuenta',
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (profile.isSuspended)
          OutlinedButton(
            onPressed: _busy ? null : _reactivate,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: const BorderSide(color: AppColors.burgundy),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reactivar cuenta'),
          )
        else
          OutlinedButton(
            onPressed: _busy ? null : _suspend,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: const BorderSide(color: AppColors.burgundy),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Suspender cuenta'),
          ),
      ],
    );
  }
}
