import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class CofradeoSearchBar extends StatelessWidget {
  const CofradeoSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  static const _fieldColor = Color(0xFF3A322C);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      style: AppTypography.bodyLarge(color: AppColors.goldPale),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        hintText: 'Buscar temas, perfiles o eventos…',
        hintStyle: AppTypography.bodyMedium(color: AppColors.goldLight),
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.goldPale,
        ),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              onPressed: () {
                controller.clear();
                onChanged?.call('');
                onClear?.call();
              },
              icon: const Icon(Icons.close, color: AppColors.goldLight),
            );
          },
        ),
        filled: true,
        fillColor: _fieldColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
