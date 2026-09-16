import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../search_design.dart';

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

  static const _fieldColor = Color(0xFF2E2824);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SearchDesign.searchHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SearchDesign.searchRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          style: AppTypography.bodyMedium(color: AppColors.goldPale).copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: AppColors.gold,
          decoration: InputDecoration(
            hintText: 'Temas, @perfiles, eventos…',
            hintStyle: AppTypography.bodyMedium(
              color: AppColors.goldLight.withValues(alpha: 0.85),
            ).copyWith(fontSize: 12),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.goldPale,
                size: 20,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
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
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.goldLight,
                    size: 16,
                  ),
                ),
              );
            },
          ),
          filled: true,
          fillColor: _fieldColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SearchDesign.searchRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SearchDesign.searchRadius),
            borderSide: BorderSide(
              color: AppColors.gold.withValues(alpha: 0.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SearchDesign.searchRadius),
            borderSide: BorderSide(
              color: AppColors.gold.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
        ),
      ),
    ),
    );
  }
}
