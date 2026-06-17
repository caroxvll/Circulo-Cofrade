import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class AuthEmailForm extends StatelessWidget {
  const AuthEmailForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.submitLabel,
    required this.onSubmit,
    this.loading = false,
    this.displayNameController,
    this.handleController,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController? displayNameController;
  final TextEditingController? handleController;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (displayNameController != null) ...[
          TextField(
            controller: displayNameController,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Nombre visible'),
          ),
          const SizedBox(height: 12),
        ],
        if (handleController != null) ...[
          TextField(
            controller: handleController,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Handle (@usuario)'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: _decoration('Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: _decoration('Contraseña'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(submitLabel, style: AppTypography.titleLarge(
                    color: AppColors.textOnDark,
                  ).copyWith(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.bodyMedium(),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burgundy),
      ),
    );
  }
}
