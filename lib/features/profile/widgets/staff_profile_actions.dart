import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';
import '../../admin/admin_provider.dart';
import '../../calendar/calendar_contributors_provider.dart';
import '../../forums/news_publishers_provider.dart';
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

  Future<void> _setNewsPublisher(bool enabled) async {
    final profile = widget.profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          enabled
              ? '¿Dejar que ${profile.handle} publique noticias?'
              : '¿Quitar el acceso a noticias de ${profile.handle}?',
        ),
        content: Text(
          enabled
              ? 'Podrá publicar noticias con su nombre, al momento. '
                  'El calendario sigue aparte: se da con «acceso a calendario».'
              : 'Dejará de poder crear noticias. Lo ya publicado sigue con su firma.',
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
            child: Text(enabled ? 'Dar acceso' : 'Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setNewsPublisher(
            profileId: profile.id,
            enabled: enabled,
          );
      ref.invalidate(isNewsPublisherProvider(profile.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? '${profile.handle} ya puede publicar noticias'
                  : '${profile.handle} ya no publica noticias',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar. ¿Ejecutaste news_publishers.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCalendarContributor(bool enabled) async {
    final profile = widget.profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          enabled
              ? '¿Dejar que ${profile.handle} proponga eventos?'
              : '¿Quitar el acceso al calendario de ${profile.handle}?',
        ),
        content: Text(
          enabled
              ? 'Podrá crear eventos. No salen solos: la Junta los aprueba en Eventos. '
                  'También podrá publicar noticias, con el verificado dorado.'
              : 'Dejará de proponer eventos. El acceso a noticias, si lo tiene, se queda.',
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
            child: Text(enabled ? 'Dar acceso' : 'Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setCalendarContributor(
            profileId: profile.id,
            enabled: enabled,
          );
      ref.invalidate(isCalendarContributorProvider(profile.id));
      ref.invalidate(isNewsPublisherProvider(profile.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? '${profile.handle} puede proponer eventos y publicar noticias'
                  : '${profile.handle} ya no propone eventos',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar. ¿Ejecutaste calendar_contributors.sql?',
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
    final canPublishNews =
        ref.watch(isNewsPublisherProvider(profile.id)).asData?.value ?? false;
    final canProposeCalendar =
        ref.watch(isCalendarContributorProvider(profile.id)).asData?.value ??
            false;

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
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _setNewsPublisher(!canPublishNews),
            icon: Icon(
              canPublishNews
                  ? Icons.newspaper
                  : Icons.newspaper_outlined,
              size: 18,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: const BorderSide(color: AppColors.burgundy),
            ),
            label: Text(
              canPublishNews
                  ? 'Quitar acceso a noticias'
                  : 'Dar acceso a noticias',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _setCalendarContributor(!canProposeCalendar),
            icon: Icon(
              canProposeCalendar
                  ? Icons.event_available
                  : Icons.event_available_outlined,
              size: 18,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: const BorderSide(color: AppColors.burgundy),
            ),
            label: Text(
              canProposeCalendar
                  ? 'Quitar acceso a calendario'
                  : 'Dar acceso a calendario',
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
