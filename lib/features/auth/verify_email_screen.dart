import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_logo.dart';
import 'auth_provider.dart';
import 'auth_error_messages.dart';
import 'data/auth_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = false;
  bool _resent = false;
  String? _error;
  bool _syncingOnOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOnOpen());
  }

  Future<void> _syncOnOpen() async {
    if (!ref.read(supabaseReadyProvider)) {
      if (mounted) setState(() => _syncingOnOpen = false);
      return;
    }
    if (!ref.read(isAuthenticatedProvider)) {
      if (mounted) setState(() => _syncingOnOpen = false);
      return;
    }

    try {
      await ref.read(authRepositoryProvider).syncAuthUser();
      if (!mounted) return;
      if (ref.read(isEmailVerifiedProvider)) {
        context.go('/calendario');
        return;
      }
    } catch (_) {
      // Si falla la red, se muestra la pantalla igualmente.
    } finally {
      if (mounted) setState(() => _syncingOnOpen = false);
    }
  }

  String get _email =>
      widget.email?.trim() ??
      ref.read(currentUserProvider)?.email ??
      '';

  Future<void> _resend() async {
    final email = _email;
    if (email.isEmpty) {
      setState(() => _error = 'No hay email para reenviar.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resent = false;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .resendSignupConfirmation(email: email);
      if (!mounted) return;
      setState(() => _resent = true);
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthErrorMessage(e));
    } on AuthUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo reenviar el email.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkVerified() async {
    if (!ref.read(isAuthenticatedProvider)) {
      final email = _email;
      final query = email.isNotEmpty
          ? '?email=${Uri.encodeComponent(email)}'
          : '';
      context.go('/login$query');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).refreshSession();
      if (!mounted) return;

      if (ref.read(isEmailVerifiedProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta confirmada')),
        );
        context.go('/calendario');
        return;
      }

      setState(
        () => _error =
            'Aún no aparece confirmado. Revisa tu bandeja o reenvía el enlace.',
      );
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthErrorMessage(e));
    } catch (_) {
      setState(() => _error = 'No se pudo comprobar el estado.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isAuthenticatedProvider);
    final emailVerified = ref.watch(isEmailVerifiedProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final displayEmail = _email;
    final blockBack = isLoggedIn && !emailVerified;

    ref.listen(isEmailVerifiedProvider, (previous, next) {
      if (previous == true || next != true) return;
      if (!ref.read(isAuthenticatedProvider) || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta confirmada')),
      );
      context.go('/calendario');
    });

    return PopScope(
      canPop: !blockBack,
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: blockBack
            ? const SizedBox(width: 56)
            : IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
              ),
        title: Text(
          'REVISA TU CORREO',
          style: AppTypography.screenAppBarTitle(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            const Center(child: AppLogo(forLogin: true, size: 200)),
            const SizedBox(height: 16),
            if (displayEmail.isNotEmpty) ...[
              Text(
                'Hemos enviado un enlace de confirmación a',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                displayEmail,
                style: AppTypography.titleLarge().copyWith(
                  color: AppColors.burgundy,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ábrelo y pulsa el enlace. Al confirmar, esta pantalla se '
                'actualizará sola o te abrirá la app.',
                style: AppTypography.bodyMedium(),
                textAlign: TextAlign.center,
              ),
            ] else
              Text(
                'Confirma tu email para activar tu cuenta.',
                style: AppTypography.bodyMedium(),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            _VerificationSteps(
              isLoggedIn: isLoggedIn,
              emailVerified: emailVerified,
            ),
            if (!supabaseReady) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Conecta Supabase con env.json para la verificación real.',
                  style: AppTypography.bodyMedium(),
                ),
              ),
            ],
            if (_resent) ...[
              const SizedBox(height: 16),
              Text(
                'Enlace reenviado. Revisa tu bandeja y la carpeta de spam.',
                style: AppTypography.bodyMedium(color: AppColors.burgundy),
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: AppTypography.bodyMedium(color: AppColors.accentRed),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            if (_syncingOnOpen)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading || !supabaseReady ? null : _checkVerified,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLoggedIn ? 'Ya confirmé' : 'Ir a iniciar sesión'),
              ),
            ),
            if (!emailVerified) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _loading || !supabaseReady || displayEmail.isEmpty
                      ? null
                      : _resend,
                  child: Text(
                    '¿No lo recibiste? Reenviar correo',
                    style: AppTypography.bodyMedium(color: AppColors.burgundy),
                  ),
                ),
              ),
            ],
            if (!isLoggedIn) ...[
              const SizedBox(height: 4),
              Text(
                'Tras confirmar el enlace, inicia sesión y tu cuenta quedará '
                'guardada en este dispositivo.',
                style: AppTypography.labelSmall(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ] else if (!emailVerified) ...[
              const SizedBox(height: 4),
              Text(
                'Si ya confirmaste en otra pestaña, espera un momento o pulsa '
                '«Ya confirmé».',
                style: AppTypography.labelSmall(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await ref.read(authRepositoryProvider).signOut();
                      },
                child: Text(
                  'Usar otra cuenta',
                  style: AppTypography.bodyMedium(color: AppColors.textMuted),
                ),
              ),
            ],
            ],
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _goBack() async {
    final repo = ref.read(authRepositoryProvider);
    if (ref.read(isAuthenticatedProvider) && !ref.read(isEmailVerifiedProvider)) {
      await repo.signOut();
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/bienvenida');
    }
  }
}

class _VerificationSteps extends StatelessWidget {
  const _VerificationSteps({
    required this.isLoggedIn,
    required this.emailVerified,
  });

  final bool isLoggedIn;
  final bool emailVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const _StepRow(
            number: 1,
            label: 'Crea tu cuenta',
            done: true,
          ),
          const SizedBox(height: 10),
          _StepRow(
            number: 2,
            label: 'Confirma el enlace del correo',
            done: emailVerified,
            active: !emailVerified,
          ),
          const SizedBox(height: 10),
          _StepRow(
            number: 3,
            label: isLoggedIn
                ? 'Entra en la app'
                : 'Inicia sesión en este dispositivo',
            done: emailVerified && isLoggedIn,
            active: emailVerified && !isLoggedIn,
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.label,
    this.done = false,
    this.active = false,
  });

  final int number;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.burgundy
        : active
            ? AppColors.burgundy
            : AppColors.textMuted;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.burgundy
                : active
                    ? AppColors.burgundy.withValues(alpha: 0.12)
                    : AppColors.background,
            border: Border.all(color: color),
          ),
          child: done
              ? const Icon(Icons.check, size: 16, color: AppColors.textOnDark)
              : Text(
                  '$number',
                  style: AppTypography.labelSmall(color: color),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium(
              color: active ? AppColors.textPrimary : AppColors.textMuted,
            ).copyWith(fontWeight: active ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
      ],
    );
  }
}
