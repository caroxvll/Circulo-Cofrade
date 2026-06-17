import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_branding.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
        goAfterAuthenticated(context, ref, redirect: widget.redirect);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: Text(
          'Crear cuenta',
          style: AppTypography.displaySmall().copyWith(fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text(
              AppBranding.joinCta,
              style: AppTypography.displaySmall(),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige un nombre y handle únicos. Las hermandades oficiales '
              'requieren verificación (ver PERFIL.md).',
              style: AppTypography.bodyMedium(),
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
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTypography.bodyMedium(color: AppColors.accentRed),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              Text(
                _info!,
                style: AppTypography.bodyMedium(color: AppColors.burgundy),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
