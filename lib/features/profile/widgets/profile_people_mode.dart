import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

enum ProfilePeopleMode { seguidores, siguiendo }

class ProfilePeopleModeNotifier extends Notifier<ProfilePeopleMode> {
  @override
  ProfilePeopleMode build() => ProfilePeopleMode.siguiendo;

  void setMode(ProfilePeopleMode mode) => state = mode;
}

/// Modo activo de la lista de personas en el perfil (Seguidores / Siguiendo).
final profilePeopleModeProvider =
    NotifierProvider<ProfilePeopleModeNotifier, ProfilePeopleMode>(
  ProfilePeopleModeNotifier.new,
);

class ProfilePeopleModeToggle extends StatelessWidget {
  const ProfilePeopleModeToggle({
    super.key,
    required this.mode,
    required this.onSelected,
  });

  final ProfilePeopleMode mode;
  final ValueChanged<ProfilePeopleMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: ProfilePeopleMode.values.map((value) {
          final selected = mode == value;
          final label = switch (value) {
            ProfilePeopleMode.seguidores => 'Seguidores',
            ProfilePeopleMode.siguiendo => 'Siguiendo',
          };
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(value),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.burgundy : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textSecondary,
                    ).copyWith(
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ProfilePeopleSearchField extends StatelessWidget {
  const ProfilePeopleSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyMedium().copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMedium(
          color: AppColors.textMuted,
        ).copyWith(fontSize: 13.5),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.goldDark,
          size: 20,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar',
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textMuted,
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.75),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.75),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.burgundy, width: 1.4),
        ),
      ),
    );
  }
}

bool profileMatchesQuery(String query, {required String name, required String handle}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return name.toLowerCase().contains(q) || handle.toLowerCase().contains(q);
}
