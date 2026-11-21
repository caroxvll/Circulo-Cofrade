import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../hermandad_season_acts_provider.dart';
import '../utils/hermandad_season_profile.dart';
import 'forum_compose_sheet_header.dart';
import 'forum_compose_sheet_layout.dart';

Future<bool> showHermandadSeasonProfileSheet(
  BuildContext context, {
  required String topicId,
  required String hermandadName,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SeasonProfileSheet(
      topicId: topicId,
      hermandadName: hermandadName,
    ),
  );
  return saved == true;
}

class _SeasonProfileSheet extends ConsumerStatefulWidget {
  const _SeasonProfileSheet({
    required this.topicId,
    required this.hermandadName,
  });

  final String topicId;
  final String hermandadName;

  @override
  ConsumerState<_SeasonProfileSheet> createState() =>
      _SeasonProfileSheetState();
}

class _SeasonProfileSheetState extends ConsumerState<_SeasonProfileSheet> {
  var _saving = false;
  HermandadSeasonProfile _profile = HermandadSeasonProfile.defaults;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await ref
        .read(hermandadSeasonProfileStoreProvider)
        .fetch(widget.topicId);
    if (!mounted) return;
    setState(() => _profile = loaded);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(hermandadSeasonProfileStoreProvider).save(
            widget.topicId,
            _profile,
          );
      ref.invalidate(hermandadSeasonProfileProvider(widget.topicId));
      ref.invalidate(hermandadSeasonActsProvider);
      ref.invalidate(hermandadSeasonActsCoverageProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar. Ejecuta hermandad_season_profile.sql.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ForumComposeSheetLayout(
      header: ForumComposeSheetTitleBar(
        closeEnabled: !_saving,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temporada de ${widget.hermandadName}',
              style: AppTypography.titleLarge(),
            ),
            const SizedBox(height: 4),
            Text(
              'Así se marcan los checks: igualá, ensayos, muda y desarmá.',
              style: AppTypography.bodyMedium(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
            const SizedBox(height: 8),
            Text('Igualá', style: AppTypography.sectionTitle()),
            const SizedBox(height: 8),
            _Choice(
              selected: !_profile.igualaSplit,
              title: 'Los dos pasos juntos',
              subtitle: 'Una sola igualá.',
              onTap: () => setState(
                () => _profile = _profile.copyWith(igualaSplit: false),
              ),
            ),
            const SizedBox(height: 8),
            _Choice(
              selected: _profile.igualaSplit,
              title: 'Cristo y Virgen por separado',
              subtitle: 'Hace falta una igualá de cada paso.',
              onTap: () => setState(
                () => _profile = _profile.copyWith(igualaSplit: true),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ensayos', style: AppTypography.sectionTitle()),
            const SizedBox(height: 8),
            _Choice(
              selected: !_profile.ensayoSplit,
              title: 'Juntos',
              subtitle: 'Los dos pasos ensayan el mismo día.',
              onTap: () => setState(
                () => _profile = _profile.copyWith(ensayoSplit: false),
              ),
            ),
            const SizedBox(height: 8),
            _Choice(
              selected: _profile.ensayoSplit,
              title: 'Cristo y Virgen por separado',
              subtitle: 'Cada paso tiene su tanda de ensayos.',
              onTap: () => setState(
                () => _profile = _profile.copyWith(ensayoSplit: true),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _profile.ensayoSplit
                  ? 'Ensayos de cada paso'
                  : 'Número de ensayos',
              style: AppTypography.labelSmall(color: AppColors.goldDark)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (var n = 1; n <= 6; n++)
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _profile.ensayoCount == n,
                    onSelected: (_) => setState(
                      () => _profile = _profile.copyWith(ensayoCount: n),
                    ),
                    selectedColor: AppColors.goldPale,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Muda y retranqueo', style: AppTypography.sectionTitle()),
            const SizedBox(height: 8),
            for (final mode in MudaRetranqueoMode.values) ...[
              _Choice(
                selected: _profile.mudaMode == mode,
                title: mode.label,
                subtitle: switch (mode) {
                  MudaRetranqueoMode.withRetranqueo =>
                    'Un acto (o los dos el mismo día) cierra el check.',
                  MudaRetranqueoMode.split =>
                    'Hace falta muda y retranqueo, en días distintos.',
                  MudaRetranqueoMode.mudaOnly =>
                    'Solo cuenta la muda. El retranqueo no entra en el check.',
                },
                onTap: () => setState(
                  () => _profile = _profile.copyWith(mudaMode: mode),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_saving ? 'Guardando…' : 'Guardar temporada'),
            ),
            const SizedBox(height: 8),
          ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.goldPale : AppColors.backgroundElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: AppColors.burgundy,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
