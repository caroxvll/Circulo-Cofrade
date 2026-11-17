import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import 'auth_layout.dart';
import 'auth_error_messages.dart';
import 'auth_provider.dart';
import 'data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Introduce tu email.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthErrorMessage(e));
    } on AuthUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'No se pudo enviar el enlace. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseReady = ref.watch(supabaseReadyProvider);

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
          'RECUPERAR ACCESO',
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
                final sectionGap = metrics.tight
                    ? 16.0
                    : (metrics.compact ? 22.0 : 28.0);

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    metrics.side,
                    metrics.belowAppBar,
                    metrics.side,
                    metrics.bottomPad,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: metrics.contentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _sent
                                  ? 'Revisa tu bandeja de entrada'
                                  : '¿Olvidaste tu contraseña?',
                              style: AppTypography.displaySmall(
                                color: AppColors.goldPale,
                              ).copyWith(fontSize: metrics.titleSize, height: 1.1),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: metrics.tight ? 8 : 12),
                            Text(
                              _sent
                                  ? 'Si existe una cuenta con ese email, recibirás un enlace '
                                        'para elegir una contraseña nueva. Comprueba también spam.'
                                  : 'Te enviaremos un enlace a tu email para restablecer la contraseña.',
                              style: AppTypography.bodyMedium(
                                color: Colors.white.withValues(alpha: 0.86),
                              ).copyWith(fontSize: metrics.bodySize),
                              textAlign: TextAlign.center,
                            ),
                            if (!supabaseReady) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.48,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Conecta Supabase con env.json para usar la recuperación real.',
                                  style: AppTypography.bodyMedium(
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            if (!_sent) ...[
                              SizedBox(height: sectionGap),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                cursorColor: AppColors.gold,
                                style: AppTypography.displaySmall(
                                  color: AppColors.goldPale,
                                ).copyWith(
                                  fontSize: metrics.fieldSize,
                                  height: 1.15,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                enabled: !_loading,
                                decoration: authDarkFieldDecoration(
                                  label: 'Email',
                                  fieldSize: metrics.fieldSize,
                                  verticalPadding: metrics.fieldPad,
                                ),
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
                              SizedBox(height: metrics.tight ? 16 : 22),
                              _GoldButton(
                                label: 'Enviar enlace',
                                height: metrics.buttonHeight,
                                loading: _loading,
                                onPressed: _loading || !supabaseReady
                                    ? null
                                    : _submit,
                              ),
                            ] else ...[
                              SizedBox(height: sectionGap),
                              _GoldButton(
                                label: 'Volver a iniciar sesión',
                                height: metrics.buttonHeight,
                                onPressed: () => context.go('/login'),
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

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.onPressed,
    required this.height,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
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
                label,
                style: AppTypography.titleLarge(
                  color: const Color(0xFF2A0710),
                ).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
