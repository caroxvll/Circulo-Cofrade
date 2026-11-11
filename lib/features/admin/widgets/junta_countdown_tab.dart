import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofrade_countdown_banner.dart';
import '../../../shared/models/liturgical_countdown_settings.dart';
import '../../calendar/liturgical_countdown_provider.dart';
import '../../calendar/utils/holy_week_countdown.dart';
import '../../forums/season_hub_settings_provider.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../../semana_santa/data/ss_live_gate_repository.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';

class JuntaCountdownTab extends ConsumerStatefulWidget {
  const JuntaCountdownTab({super.key});

  @override
  ConsumerState<JuntaCountdownTab> createState() => _JuntaCountdownTabState();
}

class _JuntaCountdownTabState extends ConsumerState<JuntaCountdownTab> {
  final _visibleDaysController = TextEditingController();
  var _enabled = true;
  DateTime? _palmOverride;
  DateTime? _easterOverride;
  var _loadedYear = 0;
  var _saving = false;
  bool? _liveEnabled;
  var _savingLive = false;
  String? _savingSeasonKey;

  @override
  void dispose() {
    _visibleDaysController.dispose();
    super.dispose();
  }

  void _syncFromSettings(LiturgicalCountdownSettings settings) {
    if (_loadedYear == settings.year) return;
    _loadedYear = settings.year;
    _enabled = settings.isEnabled;
    _palmOverride = settings.palmSundayOverride;
    _easterOverride = settings.easterSundayOverride;
    _visibleDaysController.text = settings.visibleDaysBefore.toString();
  }

  Future<void> _pickDate({required bool palm}) async {
    final initial = palm
        ? (_palmOverride ?? computedLiturgicalDates(_loadedYear).palmSunday)
        : (_easterOverride ??
              computedLiturgicalDates(_loadedYear).easterSunday);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_loadedYear, 1, 1),
      lastDate: DateTime(_loadedYear, 12, 31),
      locale: const Locale('es'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (palm) {
        _palmOverride = picked;
        _easterOverride ??= picked.add(const Duration(days: 7));
      } else {
        _easterOverride = picked;
      }
    });
  }

  LiturgicalCountdownSettings _draftSettings() {
    return LiturgicalCountdownSettings(
      year: _loadedYear,
      palmSundayOverride: _palmOverride,
      easterSundayOverride: _easterOverride,
      visibleDaysBefore: int.tryParse(_visibleDaysController.text.trim()) ?? 60,
      isEnabled: _enabled,
      usesManualDates: _palmOverride != null || _easterOverride != null,
    );
  }

  Future<void> _save() async {
    final days = int.tryParse(_visibleDaysController.text.trim());
    if (days == null ||
        days < 0 ||
        days > maxCountdownVisibleDaysBeforePalmSunday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Los días de antelación deben estar entre 0 y '
            '$maxCountdownVisibleDaysBeforePalmSunday',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(liturgicalCountdownRepositoryProvider)
          .upsert(_draftSettings());
      invalidateLiturgicalCountdown(ref, year: _loadedYear);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. ¿Ejecutaste liturgical_countdown.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _activateFromToday() async {
    final days = countdownVisibleDaysFromToday(
      DateTime.now(),
      settings: _draftSettings(),
    );
    setState(() => _visibleDaysController.text = days.toString());
    await _save();
  }

  Future<void> _resetToAutomatic() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(liturgicalCountdownRepositoryProvider)
          .clearOverrides(_loadedYear);
      await ref
          .read(liturgicalCountdownRepositoryProvider)
          .upsert(
            LiturgicalCountdownSettings(
              year: _loadedYear,
              visibleDaysBefore:
                  int.tryParse(_visibleDaysController.text) ?? 60,
              isEnabled: _enabled,
            ),
          );
      setState(() {
        _palmOverride = null;
        _easterOverride = null;
      });
      invalidateLiturgicalCountdown(ref, year: _loadedYear);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fechas automáticas restauradas')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo restaurar')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setLiveEnabled(bool enabled) async {
    setState(() {
      _liveEnabled = enabled;
      _savingLive = true;
    });
    try {
      await ref.read(ssLiveGateRepositoryProvider).setLiveEnabled(enabled);
      ref.invalidate(ssLiveMasterEnabledProvider);
      ref.invalidate(ssLiveGateProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'En directo de Semana Santa activado'
                  : 'En directo de Semana Santa en pausa',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _liveEnabled = !enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cambiar el en directo')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingLive = false);
    }
  }

  Future<void> _setSeasonMode(String configKey, SeasonHubMode mode) async {
    setState(() => _savingSeasonKey = configKey);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setAppConfig(configKey, mode.dbValue);
      ref.invalidate(seasonHubSettingsProvider);
      if (configKey == semanaSantaHubModeConfigKey) {
        ref.invalidate(ssLiveGateProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apertura de temporada actualizada')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la temporada')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSeasonKey = null);
    }
  }

  Future<void> _setSemanaSantaManualDay(String day) async {
    setState(() => _savingSeasonKey = semanaSantaManualDayConfigKey);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setAppConfig(semanaSantaManualDayConfigKey, day);
      ref.invalidate(seasonHubSettingsProvider);
      ref.invalidate(ssLiveGateProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Jornada manual: $day')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cambiar la jornada')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSeasonKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final settingsAsync = ref.watch(liturgicalCountdownSettingsProvider(year));
    final liveAsync = ref.watch(ssLiveMasterEnabledProvider);
    final seasonModesAsync = ref.watch(seasonHubSettingsProvider);
    final liveOn = _liveEnabled ?? liveAsync.asData?.value ?? false;
    final dateFormat = DateFormat("EEEE d 'de' MMMM", 'es');
    final computed = computedLiturgicalDates(year);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (settings) {
        _syncFromSettings(settings);
        final preview = cofradeCountdownFor(
          DateTime.now(),
          settings: LiturgicalCountdownSettings(
            year: year,
            palmSundayOverride: _palmOverride,
            easterSundayOverride: _easterOverride,
            visibleDaysBefore:
                int.tryParse(_visibleDaysController.text) ??
                settings.visibleDaysBefore,
            isEnabled: _enabled,
            usesManualDates: _palmOverride != null || _easterOverride != null,
          ),
        );

        return ListView(
          padding: JuntaUi.listPadding,
          children: [
            const JuntaInfoBanner(
              text:
                  'Por defecto la app calcula Ramos y Pascua sola. Aquí puedes '
                  'ajustar fechas, visibilidad o desactivar el banner.',
            ),
            const SizedBox(height: JuntaUi.sectionGap),
            Text('Apartados de temporada', style: JuntaUi.sectionTitle()),
            const SizedBox(height: 8),
            seasonModesAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => const _InfoCard(
                title: 'Apertura de temporadas',
                body: 'No se pudo cargar la configuración.',
              ),
              data: (modes) => Column(
                children: [
                  _SeasonModeCard(
                    title: 'Cuaresma',
                    subtitle:
                        'Controla la tarjeta «Ensayos abiertos» de las hermandades.',
                    value: modes.cuaresma,
                    busy: _savingSeasonKey == cuaresmaHubModeConfigKey,
                    onChanged: (mode) =>
                        _setSeasonMode(cuaresmaHubModeConfigKey, mode),
                  ),
                  const SizedBox(height: 10),
                  _SeasonModeCard(
                    title: 'Semana Santa',
                    subtitle:
                        'En automático usa la jornada real. En manual puedes simular el día elegido.',
                    value: modes.semanaSanta,
                    busy:
                        _savingSeasonKey == semanaSantaHubModeConfigKey ||
                        _savingSeasonKey == semanaSantaManualDayConfigKey,
                    onChanged: (mode) =>
                        _setSeasonMode(semanaSantaHubModeConfigKey, mode),
                    manualDay: modes.semanaSantaManualDay,
                    manualDayOptions: hermandadDirectoryDays
                        .where((day) => day != hermandadGloriasCategory)
                        .toList(),
                    onManualDayChanged: _setSemanaSantaManualDay,
                  ),
                ],
              ),
            ),
            const SizedBox(height: JuntaUi.sectionGap),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'En directo de Semana Santa',
                style: JuntaUi.cardTitle(),
              ),
              subtitle: Text(
                liveOn
                    ? 'Los avisos de la jornada abierta se pueden publicar'
                    : 'En pausa. Aunque una jornada esté forzada abierta, no deja informar',
                style: JuntaUi.caption(),
              ),
              value: liveOn,
              activeThumbColor: AppColors.burgundy,
              onChanged: _savingLive || liveAsync.isLoading
                  ? null
                  : _setLiveEnabled,
            ),
            const SizedBox(height: 8),
            _InfoCard(
              title: 'Cálculo automático ($_loadedYear)',
              body:
                  'Domingo de Ramos: ${dateFormat.format(computed.palmSunday)}\n'
                  'Domingo de Resurrección: ${dateFormat.format(computed.easterSunday)}\n\n'
                  'Pascua se obtiene con el algoritmo gregoriano (ciclo de 19 años '
                  'y correcciones del calendario). Ramos = Pascua − 7 días.',
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Mostrar cuenta atrás', style: JuntaUi.cardTitle()),
              subtitle: Text('Calendario y Foros', style: JuntaUi.caption()),
              value: _enabled,
              activeThumbColor: AppColors.burgundy,
              onChanged: _saving ? null : (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _visibleDaysController,
              keyboardType: TextInputType.number,
              style: JuntaUi.body(color: AppColors.textPrimary),
              decoration: JuntaUi.inputDecoration(
                labelText: 'Días de antelación',
                helperText:
                    'Cuándo empieza a verse el banner (0–$maxCountdownVisibleDaysBeforePalmSunday). '
                    '0 = solo desde el Domingo de Ramos.',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _activateFromToday,
                icon: const Icon(Icons.today_outlined, size: 18),
                label: const Text('Ver desde hoy'),
              ),
            ),
            const SizedBox(height: JuntaUi.sectionGap),
            Text('Fechas manuales (opcional)', style: JuntaUi.sectionTitle()),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text('Domingo de Ramos', style: JuntaUi.cardTitle()),
              subtitle: Text(
                _palmOverride == null
                    ? 'Automático: ${dateFormat.format(computed.palmSunday)}'
                    : 'Manual: ${dateFormat.format(_palmOverride!)}',
                style: JuntaUi.caption(),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: _saving ? null : () => _pickDate(palm: true),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(
                'Domingo de Resurrección',
                style: JuntaUi.cardTitle(),
              ),
              subtitle: Text(
                _easterOverride == null
                    ? 'Automático: ${dateFormat.format(computed.easterSunday)}'
                    : 'Manual: ${dateFormat.format(_easterOverride!)}',
                style: JuntaUi.caption(),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: _saving ? null : () => _pickDate(palm: false),
              ),
            ),
            if (_palmOverride != null || _easterOverride != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saving ? null : _resetToAutomatic,
                  child: const Text('Volver a fechas automáticas'),
                ),
              ),
            const SizedBox(height: 16),
            if (preview != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Vista previa ahora', style: JuntaUi.sectionTitle()),
                  const SizedBox(height: 8),
                  CofradeCountdownBanner(countdown: preview),
                ],
              )
            else
              _InfoCard(
                title: 'Vista previa ahora',
                body: _enabled
                    ? 'Fuera de la ventana visible con estos ajustes.'
                    : 'Banner desactivado.',
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar configuración'),
            ),
          ],
        );
      },
    );
  }
}

class _SeasonModeCard extends StatelessWidget {
  const _SeasonModeCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.busy,
    required this.onChanged,
    this.manualDay,
    this.manualDayOptions = const [],
    this.onManualDayChanged,
  });

  final String title;
  final String subtitle;
  final SeasonHubMode value;
  final bool busy;
  final ValueChanged<SeasonHubMode> onChanged;
  final String? manualDay;
  final List<String> manualDayOptions;
  final ValueChanged<String>? onManualDayChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: JuntaUi.cardPadding,
      decoration: JuntaUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: JuntaUi.cardTitle()),
          const SizedBox(height: 4),
          Text(subtitle, style: JuntaUi.caption()),
          const SizedBox(height: 10),
          DropdownButtonFormField<SeasonHubMode>(
            key: ValueKey('$title-${value.dbValue}'),
            initialValue: value,
            decoration: JuntaUi.inputDecoration(
              labelText: 'Estado',
              helperText: _seasonModeHelp(value),
            ),
            items: SeasonHubMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(_seasonModeLabel(mode)),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (mode) {
                    if (mode != null && mode != value) onChanged(mode);
                  },
          ),
          if (value == SeasonHubMode.open &&
              manualDay != null &&
              manualDayOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('$title-$manualDay'),
              initialValue: manualDayOptions.contains(manualDay)
                  ? manualDay
                  : manualDayOptions.first,
              isExpanded: true,
              decoration: JuntaUi.inputDecoration(
                labelText: 'Jornada manual',
                helperText:
                    'Con el directo activado, las hermandades de este día verán «Hoy sales».',
              ),
              items: [
                for (final day in manualDayOptions)
                  DropdownMenuItem(value: day, child: Text(day)),
              ],
              onChanged: busy
                  ? null
                  : (day) {
                      if (day != null && day != manualDay) {
                        onManualDayChanged?.call(day);
                      }
                    },
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

String _seasonModeLabel(SeasonHubMode mode) => switch (mode) {
  SeasonHubMode.automatic => 'Automático',
  SeasonHubMode.open => 'Abierto manualmente',
  SeasonHubMode.closed => 'Cerrado manualmente',
};

String _seasonModeHelp(SeasonHubMode mode) => switch (mode) {
  SeasonHubMode.automatic => 'Se abre cuando corresponde por fecha.',
  SeasonHubMode.open => 'Visible ahora, aunque esté fuera de fecha.',
  SeasonHubMode.closed => 'Oculto aunque la fecha automática corresponda.',
};

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: JuntaUi.cardPadding,
      decoration: JuntaUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: JuntaUi.cardTitle()),
          const SizedBox(height: 6),
          Text(body, style: JuntaUi.body()),
        ],
      ),
    );
  }
}
