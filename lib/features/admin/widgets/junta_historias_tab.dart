import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../historias/historias_provider.dart';
import '../../historias/models/historia.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';

class JuntaHistoriasTab extends ConsumerStatefulWidget {
  const JuntaHistoriasTab({super.key});

  @override
  ConsumerState<JuntaHistoriasTab> createState() => _JuntaHistoriasTabState();
}

class _JuntaHistoriasTabState extends ConsumerState<JuntaHistoriasTab> {
  var _savingHub = false;

  Future<void> _setHub(bool enabled) async {
    setState(() => _savingHub = true);
    try {
      await ref.read(adminRepositoryProvider).setAppConfig(
            historiasHubConfigKey,
            enabled ? 'on' : 'off',
          );
      ref.invalidate(historiasHubEnabledProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. Revisa que app_config e historias.sql existan.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingHub = false);
    }
  }

  Future<void> _hide(Historia historia) async {
    try {
      await ref.read(historiasRepositoryProvider).setStatus(
            historiaId: historia.id,
            status: historia.isPublished ? 'hidden' : 'published',
          );
      ref.invalidate(staffHistoriasProvider);
      ref.invalidate(publishedHistoriasProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la historia')),
      );
    }
  }

  Future<void> _delete(Historia historia) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar «${historia.title}»?'),
        content: const Text('Se eliminan también sus comentarios.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(historiasRepositoryProvider).deleteHistoria(historia.id);
      ref.invalidate(staffHistoriasProvider);
      ref.invalidate(publishedHistoriasProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo borrar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubAsync = ref.watch(historiasHubEnabledProvider);
    final hubOn = hubAsync.asData?.value ?? false;
    final books = ref.watch(staffHistoriasProvider);

    return ListView(
      padding: JuntaUi.listPadding,
      children: [
        const JuntaSectionHeader(
          title: 'Apartado Historias',
          subtitle:
              'Apagado, nadie ve la pestaña en Comunidad. Enciéndelo cuando '
              'haya cronistas listos para publicar.',
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            hubOn ? 'Visible en Comunidad' : 'Oculto',
            style: JuntaUi.body(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            hubOn
                ? 'La gente ve Historias junto a Para ti, Siguiendo y Foros.'
                : 'La pestaña no aparece hasta que la actives.',
            style: JuntaUi.caption(),
          ),
          value: hubOn,
          activeThumbColor: AppColors.burgundy,
          onChanged: _savingHub ? null : _setHub,
        ),
        const SizedBox(height: JuntaUi.sectionGap),
        const JuntaInfoBanner(
          text:
              'El sello de Cronista se concede desde el perfil de cada persona '
              '(Acciones de la Junta). No es la cuenta verificada.',
        ),
        const SizedBox(height: 16),
        const JuntaSectionHeader(
          title: 'Publicadas',
          subtitle: 'Oculta o borra si hace falta.',
        ),
        const SizedBox(height: 10),
        books.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => JuntaEmptyPanel(
            icon: Icons.error_outline,
            message: 'No se pudieron cargar las historias.',
            onRetry: () => ref.invalidate(staffHistoriasProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const JuntaEmptyPanel(
                icon: Icons.auto_stories_outlined,
                message: 'Todavía no hay historias',
                subtitle: 'Concede el sello de Cronista y activa el apartado.',
              );
            }
            return Column(
              children: [
                for (final historia in items) ...[
                  _StaffHistoriaCard(
                    historia: historia,
                    onOpen: () => context.push('/historias/${historia.id}'),
                    onToggle: () => _hide(historia),
                    onDelete: () => _delete(historia),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StaffHistoriaCard extends StatelessWidget {
  const _StaffHistoriaCard({
    required this.historia,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final Historia historia;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: JuntaUi.cardPadding,
      decoration: JuntaUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(historia.title, style: JuntaUi.cardTitle()),
          const SizedBox(height: 4),
          Text(
            '${historia.kind.label} · ${historia.authorHandle} · '
            '${historia.pageCount} pág. · '
            '${historia.isPublished ? 'publicada' : historia.isDraft ? 'borrador' : 'oculta'}',
            style: JuntaUi.caption(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onOpen, child: const Text('Leer')),
              TextButton(
                onPressed: onToggle,
                child: Text(historia.isPublished ? 'Ocultar' : 'Publicar'),
              ),
              TextButton(
                onPressed: onDelete,
                child: const Text('Borrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
