import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../shared/models/forum.dart';
import '../../forums/forums_provider.dart';
import '../admin_provider.dart';

const _seasonPillarIds = {'semana-santa', 'cuaresma', 'glorias'};

class JuntaPillarsTab extends ConsumerWidget {
  const JuntaPillarsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pillarsAsync = ref.watch(adminPillarsProvider);

    return pillarsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _EmptyState(
        icon: Icons.error_outline,
        message: 'No se pudieron cargar los pilares.',
        onRetry: () => ref.invalidate(adminPillarsProvider),
      ),
      data: (pillars) {
        if (pillars.isEmpty) {
          return const _EmptyState(
            icon: Icons.forum_outlined,
            message: 'Sin pilares en Supabase.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminPillarsProvider);
            ref.invalidate(forumPillarsProvider);
            await ref.read(adminPillarsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: pillars.length + 1,
            separatorBuilder: (_, index) =>
                index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.burgundy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Activa Cuaresma, Semana Santa o Glorias cuando toque. '
                    'Los foros permanentes también pueden cerrarse, pero no es habitual.',
                    style: AppTypography.bodyMedium().copyWith(fontSize: 13),
                  ),
                );
              }
              return _PillarAdminCard(pillar: pillars[index - 1]);
            },
          ),
        );
      },
    );
  }
}

class _PillarAdminCard extends ConsumerStatefulWidget {
  const _PillarAdminCard({required this.pillar});

  final ForumCategory pillar;

  @override
  ConsumerState<_PillarAdminCard> createState() => _PillarAdminCardState();
}

class _PillarAdminCardState extends ConsumerState<_PillarAdminCard> {
  var _busy = false;

  bool get _isSeason => _seasonPillarIds.contains(widget.pillar.id);

  Future<void> _update({bool? isEnabled, bool? isActive}) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).updatePillar(
            pillarId: widget.pillar.id,
            isEnabled: isEnabled,
            isActive: isActive,
          );
      ref.invalidate(adminPillarsProvider);
      ref.invalidate(forumPillarsProvider);
      ref.invalidate(forumPillarProvider(widget.pillar.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.pillar.name} actualizado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. ¿Ejecutaste admin_forum_pillars.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onEnabledChanged(bool value) async {
    if (!value && !_isSeason) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('¿Cerrar ${widget.pillar.name}?'),
          content: const Text(
            'Es un foro permanente. Los usuarios no podrán entrar hasta que lo reactives.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _update(isEnabled: value);
  }

  @override
  Widget build(BuildContext context) {
    final pillar = widget.pillar;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.burgundy,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(pillar.icon, color: AppColors.gold, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pillar.name,
                              style: AppTypography.titleLarge().copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (_isSeason)
                            const CofradeoBadge(label: 'Temporada'),
                          if (!pillar.isEnabled)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: CofradeoBadge(label: 'Cerrado'),
                            ),
                        ],
                      ),
                      if (pillar.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          pillar.description,
                          style: AppTypography.bodyMedium().copyWith(
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (!pillar.isEnabled &&
                          pillar.lockedLabel != null &&
                          pillar.lockedLabel!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          pillar.lockedLabel!,
                          style: AppTypography.labelSmall(
                            color: AppColors.accentRed,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Foro abierto',
                style: AppTypography.titleLarge().copyWith(fontSize: 14),
              ),
              subtitle: Text(
                pillar.isEnabled
                    ? 'Los usuarios pueden entrar y publicar'
                    : 'Bloqueado en la lista de foros',
                style: AppTypography.labelSmall(),
              ),
              value: pillar.isEnabled,
              onChanged: _busy ? null : _onEnabledChanged,
              activeThumbColor: AppColors.burgundy,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Badge «Activo»',
                style: AppTypography.titleLarge().copyWith(fontSize: 14),
              ),
              subtitle: Text(
                'Muestra la llama en la tarjeta del foro',
                style: AppTypography.labelSmall(),
              ),
              value: pillar.isActive,
              onChanged: _busy || !pillar.isEnabled
                  ? null
                  : (value) => _update(isActive: value),
              activeThumbColor: AppColors.burgundy,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, style: AppTypography.titleLarge()),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
