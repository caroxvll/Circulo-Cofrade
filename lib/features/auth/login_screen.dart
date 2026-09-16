import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import 'auth_provider.dart';
import 'auth_navigation.dart';
import 'auth_error_messages.dart';
import 'data/auth_repository.dart';
import 'pending_auth_redirect.dart';

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
      await _goAfterAuth();
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

  Future<void> _goAfterAuth() async {
    await goAfterAuthenticated(context, ref, redirect: widget.redirect);
  }

  bool get _showApple {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _runOAuth(Future<void> Function() action) async {
    ref.read(pendingAuthRedirectProvider.notifier).set(widget.redirect);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      // En móvil el login termina en el navegador; la app navega al volver
      // (deep link) vía authStateChanges en app.dart.
      if (!kIsWeb) {
        setState(() => _loading = false);
      }
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthErrorMessage(e));
    } on AuthUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo abrir Google. Inténtalo de nuevo.');
    } finally {
      if (mounted && kIsWeb) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    await _runOAuth(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> _signInWithApple() async {
    await _runOAuth(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
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
    final authRequired = ref.watch(authRequiredProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);

    return Scaffold(
      backgroundColor: AppColors.burgundyDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !authRequired,
        leading: authRequired
            ? IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/bienvenida'),
                icon: const Icon(Icons.chevron_left, color: AppColors.gold),
              )
            : IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/calendario'),
                icon: const Icon(Icons.close, color: AppColors.gold),
              ),
        title: Text(
          'INICIAR SESIÓN',
          style: AppTypography.displaySmall(color: AppColors.goldPale).copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            cacheWidth: ImageDecodeCache.px(
              context,
              MediaQuery.sizeOf(context).width,
            ),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF5A101A)),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = (constraints.maxWidth * 0.88).clamp(
                  320.0,
                  520.0,
                );
                final logoWidth = (constraints.maxWidth * 0.78).clamp(
                  280.0,
                  400.0,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 42, 24, 18),
                  children: [
                    Center(
                      child: Image.asset(
                        AppAssets.logoLogin,
                        width: logoWidth,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: ImageDecodeCache.px(context, logoWidth),
                        gaplessPlayback: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: Column(
                          children: [
                            if (!supabaseReady) ...[
                              _AuthNotice(),
                              const SizedBox(height: 20),
                            ],
                            _SocialButton(
                              label: 'Continuar con Google',
                              backgroundColor: Colors.white,
                              icon: SizedBox.square(
                                dimension: 22,
                                child: SvgPicture.asset(
                                  AppAssets.googleLogo,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              onPressed: _loading ? null : _signInWithGoogle,
                            ),
                            if (_showApple) ...[
                              const SizedBox(height: 10),
                              _SocialButton(
                                label: 'Continuar con Apple',
                                icon: const Icon(
                                  Icons.apple,
                                  color: Color(0xFF2A0710),
                                  size: 24,
                                ),
                                onPressed: _loading ? null : _signInWithApple,
                              ),
                            ],
                            const SizedBox(height: 26),
                            const _EmailDivider(),
                            const SizedBox(height: 18),
                            _LoginEmailForm(
                              emailController: _emailController,
                              passwordController: _passwordController,
                              loading: _loading,
                              onSubmit: _signInWithEmail,
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _loading
                                  ? null
                                  : () => context.push('/recuperar-contrasena'),
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: AppTypography.displaySmall(
                                  color: AppColors.goldPale,
                                ).copyWith(fontSize: 18),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: AppTypography.bodyMedium(
                                  color: AppColors.accentRed,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _loading
                                  ? null
                                  : () => context.push(
                                      '/registro${widget.redirect != null ? '?redirect=${Uri.encodeComponent(widget.redirect!)}' : ''}',
                                    ),
                              child: Text(
                                '¿No tienes cuenta? Regístrate',
                                style: AppTypography.displaySmall(
                                  color: AppColors.goldPale,
                                ).copyWith(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.48)),
      ),
      child: Text(
        'Supabase no configurado: configura env.json para activar el login real. '
        'Ver docs/SUPABASE.md.',
        style: AppTypography.bodyMedium(
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.gold;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: AppTypography.titleLarge(
            color: const Color(0xFF2A0710),
          ).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: const Color(0xFF2A0710),
          disabledBackgroundColor: bg.withValues(alpha: 0.56),
          disabledForegroundColor: const Color(
            0xFF2A0710,
          ).withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _EmailDivider extends StatelessWidget {
  const _EmailDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.gold.withValues(alpha: 0.72))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'o con email',
            style: AppTypography.titleLarge(
              color: AppColors.goldPale,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Divider(color: AppColors.gold.withValues(alpha: 0.72))),
      ],
    );
  }
}

class _LoginEmailForm extends StatelessWidget {
  const _LoginEmailForm({
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          cursorColor: AppColors.gold,
          style: AppTypography.displaySmall(
            color: AppColors.goldPale,
          ).copyWith(fontSize: 21),
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('Email'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          obscureText: true,
          cursorColor: AppColors.gold,
          style: AppTypography.displaySmall(
            color: AppColors.goldPale,
          ).copyWith(fontSize: 21),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: _fieldDecoration('Contraseña'),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: loading ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF2A0710),
              disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.56),
              disabledForegroundColor: const Color(
                0xFF2A0710,
              ).withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Entrar',
                    style: AppTypography.titleLarge(
                      color: const Color(0xFF2A0710),
                    ).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    final borderRadius = BorderRadius.circular(16);
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.displaySmall(
        color: AppColors.goldPale,
      ).copyWith(fontSize: 21),
      floatingLabelStyle: AppTypography.titleLarge(color: AppColors.gold),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.gold, width: 1.3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.gold, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
      ),
    );
  }
}
