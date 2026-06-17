import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_logo.dart';
import 'auth_provider.dart';
import 'auth_navigation.dart';
import 'auth_error_messages.dart';
import 'data/auth_repository.dart';
import 'widgets/auth_email_form.dart';
import 'widgets/social_auth_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirect});

  /// Ruta a la que volver tras login (ej. `/foros/.../tema/...`).
  final String? redirect;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      _goAfterAuth();
    } on AuthException catch (e) {
      final message = friendlyAuthErrorMessage(e);
      if (e.message.toLowerCase().contains('email not confirmed')) {
        if (!mounted) return;
        final email = _emailController.text.trim();
        final query = email.isNotEmpty
            ? '?email=${Uri.encodeComponent(email)}'
            : '';
        context.go('/verificar-email$query');
        return;
      }
      setState(() => _error = message);
    } on AuthUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goAfterAuth() {
    goAfterAuthenticated(context, ref, redirect: widget.redirect);
  }

  Future<void> _signInWithEmail() async {
    final repo = ref.read(authRepositoryProvider);
    await _run(() async {
      await repo.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final authRequired = ref.watch(authRequiredProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !authRequired,
        leading: authRequired
            ? IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/bienvenida'),
                icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
              )
            : IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/calendario'),
                icon: const Icon(Icons.close, color: AppColors.burgundy),
              ),
        title: Text(
          'Iniciar sesión',
          style: AppTypography.displaySmall().copyWith(fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const Center(child: AppLogo(forLogin: true, size: 220)),
            const SizedBox(height: 28),
            if (!supabaseReady) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Modo invitado: configura Supabase con env.json para activar el login real. '
                  'Ver docs/SUPABASE.md.',
                  style: AppTypography.bodyMedium(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            SocialAuthButtons(
              loading: _loading,
              onGoogle: () => _run(
                () => ref.read(authRepositoryProvider).signInWithGoogle(),
              ),
              onApple: () => _run(
                () => ref.read(authRepositoryProvider).signInWithApple(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o con email',
                    style: AppTypography.labelSmall(),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),
            AuthEmailForm(
              emailController: _emailController,
              passwordController: _passwordController,
              submitLabel: 'Entrar',
              loading: _loading,
              onSubmit: _signInWithEmail,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => context.push('/recuperar-contrasena'),
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: AppTypography.bodyMedium(color: AppColors.burgundy),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTypography.bodyMedium(color: AppColors.accentRed),
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => context.push(
                        '/registro${widget.redirect != null ? '?redirect=${Uri.encodeComponent(widget.redirect!)}' : ''}',
                      ),
              child: Text(
                '¿No tienes cuenta? Regístrate',
                style: AppTypography.bodyMedium(color: AppColors.burgundy),
              ),
            ),
            if (!authRequired) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : () => context.go('/calendario'),
                child: Text(
                  'Explorar sin cuenta',
                  style: AppTypography.labelSmall(color: AppColors.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
