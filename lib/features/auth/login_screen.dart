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
import 'auth_layout.dart';
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

  bool get _showApple {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _signInWithApple() async {
    ref.read(pendingAuthRedirectProvider.notifier).set(widget.redirect);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } on AppleSignInCancelled {
      // Cerró la hoja de Apple.
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthErrorMessage(e));
    } on AuthUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo continuar con Apple.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            fontSize: authAppBarTitleSize(context),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
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
                final metrics = AuthLayoutMetrics.of(context, constraints);
                final height = metrics.height;
                final width = metrics.width;
                final textScale = metrics.textScale;
                final keyboardOpen = metrics.keyboardOpen;
                final tight = metrics.tight;
                final compact = metrics.compact;
                final side = metrics.side;
                final contentWidth = metrics.contentWidth;
                final logoWidth =
                    (width * (tight ? 0.50 : compact ? 0.62 : 0.70)).clamp(
                      tight ? 128.0 : 160.0,
                      340.0,
                    );
                final topPad = keyboardOpen ? 8.0 : (tight ? 40.0 : 48.0);
                final bottomPad = tight ? 4.0 : (compact ? 8.0 : 16.0);
                final logoHeight = keyboardOpen
                    ? 88.0
                    : (height < 640
                              ? 96.0
                              : height < 720
                              ? 132.0
                              : height < 820
                              ? 176.0
                              : height < 960
                              ? 210.0
                              : 250.0) /
                          (textScale > 1.2 ? 1.25 : 1);

                final form = ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: _LoginForm(
                    supabaseReady: supabaseReady,
                    showApple: _showApple,
                    tight: tight,
                    compact: compact,
                    loading: _loading,
                    error: _error,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    onGoogle: _signInWithGoogle,
                    onApple: _signInWithApple,
                    onSubmit: _signInWithEmail,
                    onForgot: () => context.push('/recuperar-contrasena'),
                    onRegister: () => context.push(
                      '/registro${widget.redirect != null ? '?redirect=${Uri.encodeComponent(widget.redirect!)}' : ''}',
                    ),
                  ),
                );

                final logo = SizedBox(
                  width: logoWidth,
                  height: logoHeight,
                  child: Image.asset(
                    AppAssets.logoLogin,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: ImageDecodeCache.px(context, logoWidth),
                    gaplessPlayback: true,
                  ),
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(side, topPad, side, bottomPad),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (height - topPad - bottomPad).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Center(child: logo),
                        Center(child: form),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.supabaseReady,
    required this.showApple,
    required this.tight,
    required this.compact,
    required this.loading,
    required this.error,
    required this.emailController,
    required this.passwordController,
    required this.onGoogle,
    required this.onApple,
    required this.onSubmit,
    required this.onForgot,
    required this.onRegister,
  });

  final bool supabaseReady;
  final bool showApple;
  final bool tight;
  final bool compact;
  final bool loading;
  final String? error;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final gap = tight ? 8.0 : (compact ? 10.0 : 12.0);
    final linkSize = tight ? 15.0 : (compact ? 16.5 : 18.0);
    final buttonHeight = tight ? 44.0 : (compact ? 48.0 : 50.0);
    final linkPad = tight ? 2.0 : (compact ? 4.0 : 6.0);

    return Column(
      children: [
        if (!supabaseReady) ...[
          _AuthNotice(),
          SizedBox(height: tight ? 8 : (compact ? 10 : 20)),
        ],
        _SocialButton(
          label: 'Continuar con Google',
          height: buttonHeight,
          backgroundColor: Colors.white,
          icon: SizedBox.square(
            dimension: 22,
            child: SvgPicture.asset(
              AppAssets.googleLogo,
              fit: BoxFit.contain,
            ),
          ),
          onPressed: loading ? null : onGoogle,
        ),
        if (showApple) ...[
          SizedBox(height: gap),
          _SocialButton(
            label: 'Continuar con Apple',
            height: buttonHeight,
            icon: const Icon(
              Icons.apple,
              color: Color(0xFF2A0710),
              size: 24,
            ),
            onPressed: loading ? null : onApple,
          ),
        ],
        SizedBox(height: tight ? 12 : (compact ? 16 : 26)),
        const _EmailDivider(),
        SizedBox(height: tight ? 8 : (compact ? 12 : 18)),
        _LoginEmailForm(
          emailController: emailController,
          passwordController: passwordController,
          loading: loading,
          tight: tight,
          compact: compact,
          onSubmit: onSubmit,
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: linkPad,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: loading ? null : onForgot,
          child: Text(
            '¿Olvidaste tu contraseña?',
            style: AppTypography.displaySmall(
              color: AppColors.goldPale,
            ).copyWith(fontSize: linkSize, height: 1.15),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: AppTypography.bodyMedium(color: AppColors.accentRed),
            textAlign: TextAlign.center,
          ),
        ],
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: linkPad,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: loading ? null : onRegister,
          child: Text(
            '¿No tienes cuenta? Regístrate',
            style: AppTypography.displaySmall(
              color: AppColors.goldPale,
            ).copyWith(fontSize: linkSize, height: 1.15),
          ),
        ),
      ],
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
    this.height = 50,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.gold;
    return SizedBox(
      width: double.infinity,
      height: height,
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
    required this.tight,
    required this.compact,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final bool tight;
  final bool compact;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final fieldSize = tight ? 16.0 : (compact ? 18.0 : 21.0);
    final fieldGap = tight ? 8.0 : (compact ? 10.0 : 14.0);
    final buttonGap = tight ? 10.0 : (compact ? 14.0 : 22.0);
    final buttonHeight = tight ? 44.0 : (compact ? 48.0 : 50.0);
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          cursorColor: AppColors.gold,
          style: AppTypography.displaySmall(
            color: AppColors.goldPale,
          ).copyWith(fontSize: fieldSize, height: 1.15),
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('Email', fieldSize),
        ),
        SizedBox(height: fieldGap),
        TextField(
          controller: passwordController,
          obscureText: true,
          cursorColor: AppColors.gold,
          style: AppTypography.displaySmall(
            color: AppColors.goldPale,
          ).copyWith(fontSize: fieldSize, height: 1.15),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: _fieldDecoration('Contraseña', fieldSize),
        ),
        SizedBox(height: buttonGap),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
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

  InputDecoration _fieldDecoration(String label, double fieldSize) {
    final borderRadius = BorderRadius.circular(16);
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.displaySmall(
        color: AppColors.goldPale,
      ).copyWith(fontSize: fieldSize, height: 1.15),
      floatingLabelStyle: AppTypography.titleLarge(color: AppColors.gold),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.08),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: tight ? 8 : (compact ? 10 : 14),
      ),
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
