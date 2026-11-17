import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../auth_layout.dart';

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
    this.dark = false,
    this.fieldSize = 20,
    this.fieldPadding = 14,
    this.buttonHeight = 50,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController? displayNameController;
  final TextEditingController? handleController;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool loading;
  final bool dark;
  final double fieldSize;
  final double fieldPadding;
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (displayNameController != null) ...[
          TextField(
            controller: displayNameController,
            cursorColor: dark ? AppColors.gold : null,
            style: _fieldStyle(),
            textInputAction: TextInputAction.next,
            decoration: _decoration('Nombre visible'),
          ),
          const SizedBox(height: 12),
        ],
        if (handleController != null) ...[
          TextField(
            controller: handleController,
            cursorColor: dark ? AppColors.gold : null,
            style: _fieldStyle(),
            textInputAction: TextInputAction.next,
            decoration: _decoration('Handle (@usuario)'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          cursorColor: dark ? AppColors.gold : null,
          style: _fieldStyle(),
          textInputAction: TextInputAction.next,
          decoration: _decoration('Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: true,
          cursorColor: dark ? AppColors.gold : null,
          style: _fieldStyle(),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: _decoration('Contraseña'),
        ),
        SizedBox(height: fieldPadding + 8),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: FilledButton(
            onPressed: loading ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: dark ? AppColors.gold : AppColors.burgundy,
              foregroundColor: dark
                  ? const Color(0xFF2A0710)
                  : AppColors.textOnDark,
              disabledBackgroundColor: dark
                  ? AppColors.gold.withValues(alpha: 0.56)
                  : null,
              disabledForegroundColor: dark
                  ? const Color(0xFF2A0710).withValues(alpha: 0.6)
                  : null,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dark ? 14 : 12),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    submitLabel,
                    style: AppTypography.titleLarge(
                      color: dark
                          ? const Color(0xFF2A0710)
                          : AppColors.textOnDark,
                    ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  TextStyle? _fieldStyle() {
    if (!dark) return null;
    return AppTypography.displaySmall(
      color: AppColors.goldPale,
    ).copyWith(fontSize: fieldSize, height: 1.15);
  }

  InputDecoration _decoration(String label) {
    if (dark) {
      return authDarkFieldDecoration(
        label: label,
        fieldSize: fieldSize,
        verticalPadding: fieldPadding,
      );
    }

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
