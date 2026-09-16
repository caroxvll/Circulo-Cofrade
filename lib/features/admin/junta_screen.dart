import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../permissions/permissions_provider.dart';
import 'widgets/junta_shell.dart';

class JuntaScreen extends ConsumerWidget {
  const JuntaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isJunta = ref.watch(isJuntaMemberProvider);

    if (!isJunta) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/perfil'),
              ),
              const SizedBox(height: 24),
              Text(
                'Acceso restringido',
                style: AppTypography.displaySmall(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Solo la Junta de Gobierno puede acceder a este panel.',
                style: AppTypography.bodyMedium(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/perfil'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                ),
                child: const Text('Volver al perfil'),
              ),
            ],
          ),
        ),
      );
    }

    final isAdmin = ref.watch(isAdminProvider);
    return JuntaShell(isAdmin: isAdmin);
  }
}
