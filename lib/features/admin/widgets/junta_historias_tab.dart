import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../historias/historias_provider.dart';
import '../../historias/models/historia.dart';
import '../../historias/widgets/historia_compose_sheet.dart';
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

  Future<void> _refreshLists() async {
    ref.invalidate(staffHistoriasProvider);
    ref.invalidate(publishedHistoriasFeedProvider);
    ref.invalidate(publishedHistoriasProvider);
    ref.invalidate(myHistoriasProvider);
  }

  Future<void> _approve(Historia historia) async {
    try {
      await ref.read(historiasRepositoryProvider).setStatus(
            historiaId: historia.id,
            status: 'published',
            clearReviewNote: true,
          );
      await _refreshLists();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${historia.title}» ya está en El Cronicón.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo aprobar')),
      );
    }
  }

  Future<void> _returnToAuthor(Historia historia) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Devolver «${historia.title}»?'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          maxLength: 280,
          decoration: const InputDecoration(
            hintText: 'Motivo para el cronista (opcional)',
          ),
        ),
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
            child: const Text('Devolver'),
          ),
        ],
      ),
    );
    final note = noteCtrl.text;
    noteCtrl.dispose();
    if (confirmed != true) return;
    try {
      await ref.read(historiasRepositoryProvider).setStatus(
            historiaId: historia.id,
            status: 'draft',
            reviewNote: note,
          );
      await _refreshLists();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo devolver')),
      );
    }
  }

  Future<void> _edit(Historia historia) async {
    final saved = await showHistoriaComposeSheet(
      context,
      existing: historia,
    );
    if (saved) {
      await _refreshLists();
      ref.invalidate(historiaByIdProvider(historia.id));
    }
  }

  Future<void> _hide(Historia historia) async {
    try {
      await ref.read(historiasRepositoryProvider).setStatus(
            historiaId: historia.id,
            status: historia.isPublished ? 'hidden' : 'published',
          );
      ref.invalidate(staffHistoriasProvider);
      ref.invalidate(publishedHistoriasFeedProvider);
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
      ref.invalidate(publishedHistoriasFeedProvider);
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

    return Stack(
      children: [
        ListView(
          padding: JuntaUi.listPadding,
          children: [
            const JuntaSectionHeader(
              title: 'El Cronicón',
              subtitle:
                  'El sello de Círculo Cofrade para libros y artículos. '
                  'Apagado, la gente no ve la pestaña. Tú sí puedes escribir. '
                  'Enciéndelo cuando haya cronistas.',
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
                    ? 'La gente ve El Cronicón junto a Para ti, Siguiendo y Foros.'
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
                  'El cronista envía el libro o artículo a revisión. '
                  'Tú lo apruebas y sale en El Cronicón. El admin puede publicar al momento. '
                  'El sello de Cronista se concede desde el perfil; no es la cuenta verificada.',
            ),
            const SizedBox(height: 16),
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
                final pending = items
                    .where((item) => item.isPendingReview)
                    .toList(growable: false);
                final rest = items
                    .where((item) => !item.isPendingReview)
                    .toList(growable: false);
                if (items.isEmpty) {
                  return const JuntaEmptyPanel(
                    icon: Icons.auto_stories_outlined,
                    message: 'Todavía no hay obras en El Cronicón',
                    subtitle:
                        'Escribe la primera o concede el sello de Cronista.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const JuntaSectionHeader(
                      title: 'Pendientes de revisión',
                      subtitle:
                          'Lo que envían los cronistas. Aprueba para que salga, o devuélvelo.',
                    ),
                    const SizedBox(height: 10),
                    if (pending.isEmpty)
                      Text(
                        'Nada en cola.',
                        style: JuntaUi.caption(),
                      )
                    else
                      for (final historia in pending) ...[
                        _StaffHistoriaCard(
                          historia: historia,
                          onOpen: () =>
                              context.push('/historias/${historia.id}'),
                          onEdit: () => _edit(historia),
                          onApprove: () => _approve(historia),
                          onReturn: () => _returnToAuthor(historia),
                          onDelete: () => _delete(historia),
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: JuntaUi.sectionGap),
                    const JuntaSectionHeader(
                      title: 'Publicadas y taller',
                      subtitle: 'Oculta o borra si hace falta.',
                    ),
                    const SizedBox(height: 10),
                    for (final historia in rest) ...[
                      _StaffHistoriaCard(
                        historia: historia,
                        onOpen: () =>
                            context.push('/historias/${historia.id}'),
                        onEdit: () => _edit(historia),
                        onToggle: () => _hide(historia),
                        onDelete: () => _delete(historia),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 72),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final created = await showHistoriaPublishSheet(context);
              if (created) {
                ref.invalidate(staffHistoriasProvider);
                ref.invalidate(publishedHistoriasFeedProvider);
                ref.invalidate(publishedHistoriasProvider);
                ref.invalidate(myHistoriasProvider);
              }
            },
            backgroundColor: AppColors.burgundy,
            foregroundColor: AppColors.textOnDark,
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('Publicar'),
          ),
        ),
      ],
    );
  }
}

class _StaffHistoriaCard extends StatelessWidget {
  const _StaffHistoriaCard({
    required this.historia,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.onToggle,
    this.onApprove,
    this.onReturn,
  });

  final Historia historia;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggle;
  final VoidCallback? onApprove;
  final VoidCallback? onReturn;

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
            '${historia.visibilityLabel.toLowerCase()}',
            style: JuntaUi.caption(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onOpen, child: const Text('Leer')),
              TextButton(onPressed: onEdit, child: const Text('Editar')),
              if (onApprove != null)
                TextButton(onPressed: onApprove, child: const Text('Aprobar')),
              if (onReturn != null)
                TextButton(onPressed: onReturn, child: const Text('Devolver')),
              if (onToggle != null)
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
