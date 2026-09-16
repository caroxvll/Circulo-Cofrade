import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../calendar_provider.dart';
import '../models/organizer_logo.dart';
import 'organizer_logo_edit_sheet.dart';

class OrganizerPickerSheet extends ConsumerStatefulWidget {
  const OrganizerPickerSheet({
    super.key,
    this.selectOnTap = true,
  });

  final bool selectOnTap;

  static Future<OrganizerLogo?> show(
    BuildContext context, {
    bool selectOnTap = true,
  }) {
    return showModalBottomSheet<OrganizerLogo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => OrganizerPickerSheet(selectOnTap: selectOnTap),
    );
  }

  @override
  ConsumerState<OrganizerPickerSheet> createState() =>
      _OrganizerPickerSheetState();
}

class _OrganizerPickerSheetState extends ConsumerState<OrganizerPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  var _query = '';
  var _loading = true;
  List<OrganizerLogo> _results = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_runSearch(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (query == _query) return;
      _query = query;
      unawaited(_runSearch(query));
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await ref
          .read(calendarRepositoryProvider)
          .searchOrganizerLogos(query);
      if (!mounted || query != _query) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || query != _query) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<void> _editItem(OrganizerLogo item) async {
    final saved = await showOrganizerLogoEditSheet(context, ref, item: item);
    if (saved == true) {
      invalidateCalendarData(ref, DateTime.now());
      invalidateOrganizerLogos(ref);
      await _runSearch(_query);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escudo actualizado')),
        );
      }
    }
  }

  Future<void> _deleteItem(OrganizerLogo item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar escudo?'),
        content: Text(
          'Se quitará «${item.displayLabel}» de la biblioteca. '
          'Los eventos ya publicados no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(calendarRepositoryProvider)
          .deleteOrganizerLogo(item.organizerKey);
      invalidateOrganizerLogos(ref);
      await _runSearch(_query);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escudo eliminado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el escudo')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(isCalendarEditorProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: cofradeoSheetBottomPadding(context, extra: 0),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.selectOnTap
                            ? 'Biblioteca de escudos'
                            : 'Gestionar escudos',
                        style: AppTypography.displaySmall(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (canManage && !widget.selectOnTap)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Edita el nombre o el escudo, o elimina entradas que ya no uses.',
                    style: AppTypography.bodyMedium(color: AppColors.textMuted),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: !widget.selectOnTap,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar hermandad o banda…',
                    hintStyle:
                        AppTypography.bodyMedium(color: AppColors.textMuted),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.goldDark),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.gold, width: 1.4),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(24),
                            children: [
                              Text(
                                _query.isEmpty
                                    ? 'Aún no hay escudos guardados.\nSube uno al publicar un evento.'
                                    : 'No hay escudos que coincidan con «$_query».',
                                style: AppTypography.bodyMedium(),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return _OrganizerLogoTile(
                                item: item,
                                canManage: canManage,
                                selectOnTap: widget.selectOnTap,
                                onSelect: () => Navigator.pop(context, item),
                                onEdit: () => _editItem(item),
                                onDelete: () => _deleteItem(item),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrganizerLogoTile extends StatelessWidget {
  const _OrganizerLogoTile({
    required this.item,
    required this.canManage,
    required this.selectOnTap,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final OrganizerLogo item;
  final bool canManage;
  final bool selectOnTap;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: selectOnTap ? onSelect : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              EventTypeIcon(
                type: EventType.evento,
                size: 44,
                customIconUrl: item.hasLogo ? item.logoUrl : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayLabel,
                      style: AppTypography.titleLarge().copyWith(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!item.hasLogo)
                      Text(
                        'Sin escudo guardado',
                        style: AppTypography.labelSmall(),
                      ),
                  ],
                ),
              ),
              if (canManage) ...[
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppColors.burgundy,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.accentRed,
                  visualDensity: VisualDensity.compact,
                ),
              ],
              if (selectOnTap)
                const Icon(Icons.chevron_right, color: AppColors.burgundy),
            ],
          ),
        ),
      ),
    );
  }
}
