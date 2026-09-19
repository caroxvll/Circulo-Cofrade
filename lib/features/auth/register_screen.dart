import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_branding.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import 'auth_provider.dart';
import 'auth_navigation.dart';
import 'auth_error_messages.dart';
import 'data/auth_repository.dart';
import 'pending_auth_redirect.dart';
import 'widgets/auth_email_form.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.redirect});

  final String? redirect;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      _info = null;
    });
    try {
      await action();
      if (!mounted) return;
      // En móvil el OAuth termina en el navegador; la app navega al volver
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

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    if (_passwordController.text.length < 8) {
      setState(() {
        _loading = false;
        _error = 'La contraseña debe tener al menos 8 caracteres.';
      });
      return;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
        handle: _handleController.text,
      );

      if (!mounted) return;

      final user = response.user;
      final verified = user?.emailConfirmedAt != null;

      if (response.session != null && verified) {
        await goAfterAuthenticated(context, ref, redirect: widget.redirect);
        return;
      }

      final email = Uri.encodeComponent(_emailController.text.trim());
      context.go('/verificar-email?email=$email');
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthErrorMessage(e));
    } on AuthUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo crear la cuenta.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.burgundyDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.gold),
        ),
        title: Text(
          'CREAR CUENTA',
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

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 76, 24, 28),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppBranding.joinCta,
                              style: AppTypography.displaySmall(
                                color: AppColors.goldPale,
                              ).copyWith(fontSize: 28),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 22),
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
                            const SizedBox(height: 22),
                            const _EmailDivider(),
                            const SizedBox(height: 18),
                            AuthEmailForm(
                              displayNameController: _displayNameController,
                              handleController: _handleController,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              submitLabel: 'Registrarme',
                              loading: _loading,
                              onSubmit: _register,
                              dark: true,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: AppTypography.bodyMedium(
                                  color: AppColors.accentRed,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (_info != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _info!,
                                style: AppTypography.bodyMedium(
                                  color: AppColors.goldPale,
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
                                      '/login${widget.redirect != null ? '?redirect=${Uri.encodeComponent(widget.redirect!)}' : ''}',
                                    ),
                              child: Text(
                                '¿Ya tienes cuenta? Inicia sesión',
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
