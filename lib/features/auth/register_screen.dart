import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                            const SizedBox(height: 10),
                            Text(
                              'Elige un nombre y handle únicos. Las hermandades oficiales '
                              'requieren verificación.',
                              style: AppTypography.bodyMedium(
                                color: Colors.white.withValues(alpha: 0.86),
                              ).copyWith(fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
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
