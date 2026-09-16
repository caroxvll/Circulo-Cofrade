import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import 'auth_error_messages.dart';
import 'auth_provider.dart';
import 'data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(
        () => _error = 'La contraseña debe tener al menos 8 caracteres.',
      );
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(newPassword: password);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
      context.go('/calendario');
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthErrorMessage(e));
    } on AuthUnavailableException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'No se pudo guardar la contraseña. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);

    return Scaffold(
      backgroundColor: AppColors.burgundyDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: user == null,
        leading: user == null
            ? IconButton(
                onPressed: () => context.go('/recuperar-contrasena'),
                icon: const Icon(Icons.chevron_left, color: AppColors.gold),
              )
            : null,
        title: Text(
          'NUEVA CONTRASEÑA',
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
                  padding: const EdgeInsets.fromLTRB(24, 84, 24, 28),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (user == null) ...[
                              Text(
                                'Enlace no válido',
                                style: AppTypography.displaySmall(
                                  color: AppColors.goldPale,
                                ).copyWith(fontSize: 27),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'El enlace ha expirado o ya se usó. Solicita uno nuevo.',
                                style: AppTypography.bodyMedium(
                                  color: Colors.white.withValues(alpha: 0.86),
                                ).copyWith(fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              _GoldButton(
                                label: 'Solicitar nuevo enlace',
                                onPressed: () =>
                                    context.go('/recuperar-contrasena'),
                              ),
                            ] else ...[
                              Text(
                                'Elige una contraseña nueva',
                                style: AppTypography.displaySmall(
                                  color: AppColors.goldPale,
                                ).copyWith(fontSize: 27),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Mínimo 8 caracteres. Tras guardar entrarás directamente.',
                                style: AppTypography.bodyMedium(
                                  color: Colors.white.withValues(alpha: 0.86),
                                ).copyWith(fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                cursorColor: AppColors.gold,
                                style: _fieldStyle(),
                                textInputAction: TextInputAction.next,
                                enabled: !_loading && supabaseReady,
                                decoration: _fieldDecoration(
                                  'Nueva contraseña',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _confirmController,
                                obscureText: true,
                                cursorColor: AppColors.gold,
                                style: _fieldStyle(),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                enabled: !_loading && supabaseReady,
                                decoration: _fieldDecoration(
                                  'Repetir contraseña',
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
                              const SizedBox(height: 22),
                              _GoldButton(
                                label: 'Guardar contraseña',
                                loading: _loading,
                                onPressed: _loading || !supabaseReady
                                    ? null
                                    : _submit,
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

  TextStyle _fieldStyle() {
    return AppTypography.displaySmall(
      color: AppColors.goldPale,
    ).copyWith(fontSize: 21);
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
      disabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.52)),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
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
