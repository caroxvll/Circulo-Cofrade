import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../ads/ads_provider.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/utils/featured_topic_ads.dart';
import '../../calendar/calendar_provider.dart';
import '../junta_ui.dart';

/// Zonas globales donde se puede poner un local de golpe (sin evento).
const packAdPlacements = <AdPlacement>[
  AdPlacement.forumsTop,
  AdPlacement.forumsMiddle,
  AdPlacement.featuredTopic,
  AdPlacement.hermandades,
  AdPlacement.calendar,
  AdPlacement.search,
  AdPlacement.noticias,
];

String placementCommercialName(AdPlacement placement) {
  return switch (placement) {
    AdPlacement.forumsTop => 'Lista de Foros · banner',
    AdPlacement.forumsEvent => 'Dentro de un foro · Evento patrocinado',
    AdPlacement.forumsMiddle => 'Dentro de un foro · Banner',
    AdPlacement.featuredTopic => 'Tema destacado · banner',
    AdPlacement.hermandades => 'Hermandades · banner',
    AdPlacement.calendar => 'Calendario · banner',
    AdPlacement.search => 'Buscar · banner',
    AdPlacement.noticias => 'Noticias · banner',
    AdPlacement.profile => 'Perfil',
    AdPlacement.home => 'Inicio',
  };
}

String placementWhereHint(AdPlacement placement) {
  return switch (placement) {
    AdPlacement.forumsTop =>
      'Sale en la lista principal de foros (encima de la barra inferior).',
    AdPlacement.forumsEvent =>
      'Tarjeta de evento tras los temas fijados, dentro del foro elegido.',
    AdPlacement.forumsMiddle =>
      'Banner «Publicidad» en el listado de temas (todos los foros).',
    AdPlacement.featuredTopic =>
      'Banner en Cuaresma, Semana Santa y Glorias.',
    AdPlacement.hermandades =>
      'Banner en el canal Hermandades (listado por días).',
    AdPlacement.calendar => 'Banner en la pestaña Calendario.',
    AdPlacement.search => 'Banner en Buscar (pantalla inicial, sin resultados).',
    AdPlacement.noticias =>
      'Banner anclado en Noticias (encima de la barra inferior).',
    AdPlacement.profile => 'Reservado · perfil.',
    AdPlacement.home => 'Reservado · inicio.',
  };
}

String adForumLabel(String forumId) {
  return switch (forumId) {
    'foro-cofradiero' => 'Círculo Cofrade',
    'pentagrama-cofrade' => 'Pentagrama Cofrade',
    'martillo-trabajadera' => 'Martillo y Trabajadera',
    'hermandades' => 'Hermandades',
    _ => forumId,
  };
}

AdPlacement placementFromValue(String value) {
  return AdPlacement.values.firstWhere(
    (placement) => placement.value == value,
    orElse: () => AdPlacement.forumsTop,
  );
}

String adTargetDetail(
  SponsoredAd ad, {
  List<CalendarEvent> events = const [],
}) {
  switch (ad.placement) {
    case AdPlacement.forumsMiddle:
    case AdPlacement.forumsEvent:
      final forum = ad.forumId == null
          ? 'Todos los foros'
          : adForumLabel(ad.forumId!);
      if (ad.placement == AdPlacement.forumsEvent) {
        final eventTitle = _eventTitle(ad.calendarEventId, events);
        if (eventTitle != null) return '$forum · Evento: $eventTitle';
        if (ad.calendarEventId == null || ad.calendarEventId!.trim().isEmpty) {
          return '$forum · Todos los eventos (hoy/futuros)';
        }
        return '$forum · Evento patrocinado';
      }
      return 'Foro: $forum';
    case AdPlacement.featuredTopic:
      final topic = ad.topicId == null
          ? 'Todos los destacados'
          : featuredTopicAdLabel(ad.topicId!);
      return 'Tema: $topic';
    case AdPlacement.forumsTop:
      return 'Pantalla: lista principal de Foros';
    case AdPlacement.hermandades:
      return 'Pantalla: canal Hermandades';
    case AdPlacement.calendar:
      return 'Pantalla: Calendario';
    case AdPlacement.search:
      return 'Pantalla: Buscar (inicio)';
    case AdPlacement.noticias:
      return 'Pantalla: Noticias';
    case AdPlacement.home:
      return 'Pantalla: Inicio';
    case AdPlacement.profile:
      return 'Pantalla: Perfil';
  }
}

String? _eventTitle(String? eventId, List<CalendarEvent> events) {
  final id = eventId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final event in events) {
    if (event.id == id) return event.title;
  }
  return null;
}

Future<void> showAdStatsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const _AdStatsSheet(),
  );
}

Future<void> showSponsorPackSheet(
  BuildContext context, {
  required List<PackSponsorOption> sponsors,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _SponsorPackSheet(sponsors: sponsors),
  );
}

class PackSponsorOption {
  const PackSponsorOption({
    required this.name,
    required this.targetUrl,
    this.imageUrl,
    this.sponsorLogoUrl,
  });

  final String name;
  final String targetUrl;
  final String? imageUrl;
  final String? sponsorLogoUrl;
}

class _AdStatsSheet extends ConsumerStatefulWidget {
  const _AdStatsSheet();

  @override
  ConsumerState<_AdStatsSheet> createState() => _AdStatsSheetState();
}

enum _StatsPeriodKind { currentMonth, previousMonth, custom, allTime }

class _AdStatsSheetState extends ConsumerState<_AdStatsSheet> {
  var _kind = _StatsPeriodKind.currentMonth;
  DateTime? _customFrom;
  DateTime? _customToInclusive;

  DateTime _monthStart(DateTime value) => DateTime(value.year, value.month);

  DateTime _nextMonthStart(DateTime value) =>
      DateTime(value.year, value.month + 1);

  AdStatsRange get _range {
    final now = DateTime.now();
    switch (_kind) {
      case _StatsPeriodKind.currentMonth:
        final start = _monthStart(now);
        return (from: start, to: _nextMonthStart(start));
      case _StatsPeriodKind.previousMonth:
        final start = _monthStart(DateTime(now.year, now.month - 1));
        return (from: start, to: _nextMonthStart(start));
      case _StatsPeriodKind.custom:
        final from = _customFrom;
        final toDay = _customToInclusive;
        if (from == null || toDay == null) {
          final start = _monthStart(now);
          return (from: start, to: _nextMonthStart(start));
        }
        final start = DateTime(from.year, from.month, from.day);
        final endExclusive = DateTime(toDay.year, toDay.month, toDay.day)
            .add(const Duration(days: 1));
        return (from: start, to: endExclusive);
      case _StatsPeriodKind.allTime:
        return (from: null, to: null);
    }
  }

  String get _periodLabel {
    final range = _range;
    switch (_kind) {
      case _StatsPeriodKind.currentMonth:
      case _StatsPeriodKind.previousMonth:
        return _capitalize(DateFormat('MMMM yyyy', 'es').format(range.from!));
      case _StatsPeriodKind.custom:
        final from = range.from!;
        final to = range.to!.subtract(const Duration(days: 1));
        final fmt = DateFormat('d MMM yyyy', 'es');
        return '${fmt.format(from)} – ${fmt.format(to)}';
      case _StatsPeriodKind.allTime:
        return 'Todo el tiempo';
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _csv(
    List<SponsoredAd> ads,
    List<AdStatisticsRow> stats,
    List<CalendarEvent> events,
  ) {
    final byId = {for (final ad in ads) ad.id: ad};
    final buffer = StringBuffer(
      'periodo,marca,zona,detalle,impresiones,clics,ctr_porcentaje\n',
    );
    final periodo = _periodLabel.replaceAll(',', ' ');
    for (final row in stats) {
      if (row.trackedImpressions <= 0 && row.clicks <= 0) continue;
      final ad = byId[row.id];
      final name = row.displayName.replaceAll(',', ' ');
      final zone = placementCommercialName(
        placementFromValue(row.placement),
      ).replaceAll(',', ' ');
      final detail = (ad == null ? '' : adTargetDetail(ad, events: events))
          .replaceAll(',', ' ');
      buffer.writeln(
        '$periodo,$name,$zone,$detail,${row.trackedImpressions},${row.clicks},${row.ctr}',
      );
    }
    return buffer.toString();
  }

  Map<AdPlacement, List<({AdStatisticsRow stat, SponsoredAd? ad})>> _grouped(
    List<SponsoredAd> ads,
    List<AdStatisticsRow> stats,
  ) {
    final byId = {for (final ad in ads) ad.id: ad};
    final map = <AdPlacement, List<({AdStatisticsRow stat, SponsoredAd? ad})>>{};
    for (final stat in stats) {
      if (stat.trackedImpressions <= 0 && stat.clicks <= 0) continue;
      final placement = placementFromValue(stat.placement);
      map.putIfAbsent(placement, () => []).add((
        stat: stat,
        ad: byId[stat.id],
      ));
    }
    for (final list in map.values) {
      list.sort(
        (a, b) =>
            b.stat.trackedImpressions.compareTo(a.stat.trackedImpressions),
      );
    }
    return map;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialStart = _customFrom ?? _monthStart(now);
    final initialEnd =
        _customToInclusive ?? DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Periodo del informe',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _kind = _StatsPeriodKind.custom;
      _customFrom = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _customToInclusive = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
    });
  }

  Widget _periodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.burgundy.withValues(alpha: 0.14),
      checkmarkColor: AppColors.burgundy,
      labelStyle: JuntaUi.caption(
        color: selected ? AppColors.burgundy : AppColors.textSecondary,
      ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
      side: BorderSide(
        color: selected ? AppColors.burgundy : AppColors.border,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adsAsync = ref.watch(adminAdsProvider);
    final statsAsync = ref.watch(adminAdStatisticsProvider(_range));
    final events =
        ref.watch(sponsorshipEventPickerProvider).asData?.value ??
            const <CalendarEvent>[];
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final now = DateTime.now();
    final currentLabel = _capitalize(
      DateFormat('MMM yyyy', 'es').format(_monthStart(now)),
    );
    final previousLabel = _capitalize(
      DateFormat('MMM yyyy', 'es').format(
        _monthStart(DateTime(now.year, now.month - 1)),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Informe de publicidad',
                  style: JuntaUi.sectionTitle(color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                color: AppColors.textMuted,
              ),
            ],
          ),
          Text(
            'Resultados del periodo · vistas ≥ 50 % un segundo, y clics. '
            'Agrupado por zona (foro, tema, evento o pantalla).',
            style: JuntaUi.caption(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _periodChip(
                label: currentLabel,
                selected: _kind == _StatsPeriodKind.currentMonth,
                onTap: () => setState(() => _kind = _StatsPeriodKind.currentMonth),
              ),
              _periodChip(
                label: previousLabel,
                selected: _kind == _StatsPeriodKind.previousMonth,
                onTap: () =>
                    setState(() => _kind = _StatsPeriodKind.previousMonth),
              ),
              _periodChip(
                label: _kind == _StatsPeriodKind.custom
                    ? _periodLabel
                    : 'Personalizado',
                selected: _kind == _StatsPeriodKind.custom,
                onTap: _pickCustomRange,
              ),
              _periodChip(
                label: 'Todo',
                selected: _kind == _StatsPeriodKind.allTime,
                onTap: () => setState(() => _kind = _StatsPeriodKind.allTime),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Periodo: $_periodLabel',
            style: JuntaUi.caption().copyWith(
              color: AppColors.burgundyDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          adsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              'No se pudieron cargar los anuncios.',
              style: JuntaUi.body(color: AppColors.accentRed),
            ),
            data: (ads) => statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(
                'No se pudo cargar el informe. ¿Ejecutaste '
                'ads_statistics_period.sql en Supabase?',
                style: JuntaUi.body(color: AppColors.accentRed),
              ),
              data: (stats) {
                final grouped = _grouped(ads, stats);
                if (grouped.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Sin vistas ni clics en $_periodLabel.',
                      style: JuntaUi.caption(color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final ordered = [
                  ...packAdPlacements.where(grouped.containsKey),
                  ...grouped.keys.where((p) => !packAdPlacements.contains(p)),
                ];
                final activeStats = stats
                    .where((s) => s.trackedImpressions > 0 || s.clicks > 0)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: _csv(ads, activeStats, events),
                                ),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'CSV copiado · $_periodLabel',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Copiar CSV'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final stamp = DateFormat(
                                'yyyyMMdd_HHmm',
                              ).format(DateTime.now());
                              await SharePlus.instance.share(
                                ShareParams(
                                  text: _csv(ads, activeStats, events),
                                  subject:
                                      'Cofradeo · informe $_periodLabel $stamp',
                                  title: 'Informe publicidad',
                                ),
                              );
                            },
                            icon: const Icon(Icons.ios_share, size: 16),
                            label: const Text('Compartir'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.burgundy,
                              foregroundColor: AppColors.textOnDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.48,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final placement in ordered)
                            _StatsZoneGroup(
                              placement: placement,
                              rows: grouped[placement]!,
                              events: events,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsZoneGroup extends StatelessWidget {
  const _StatsZoneGroup({
    required this.placement,
    required this.rows,
    required this.events,
  });

  final AdPlacement placement;
  final List<({AdStatisticsRow stat, SponsoredAd? ad})> rows;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final totalViews = rows.fold<int>(
      0,
      (sum, row) => sum + row.stat.trackedImpressions,
    );
    final totalClicks = rows.fold<int>(
      0,
      (sum, row) => sum + row.stat.clicks,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: rows.length <= 3,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Text(
              placementCommercialName(placement),
              style: JuntaUi.cardTitle(),
            ),
            subtitle: Text(
              '${rows.length} pieza${rows.length == 1 ? '' : 's'} · '
              '$totalViews vistas · $totalClicks clics',
              style: JuntaUi.caption(),
            ),
            children: [
              Text(
                placementWhereHint(placement),
                style: JuntaUi.caption(color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              for (final row in rows) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.stat.displayName, style: JuntaUi.cardTitle()),
                      if (row.ad != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          adTargetDetail(row.ad!, events: events),
                          style: JuntaUi.caption().copyWith(
                            color: AppColors.burgundyDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${row.stat.trackedImpressions} vistas · '
                        '${row.stat.clicks} clics · CTR ${row.stat.ctr}%',
                        style: JuntaUi.body().copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SponsorPackSheet extends ConsumerStatefulWidget {
  const _SponsorPackSheet({required this.sponsors});

  final List<PackSponsorOption> sponsors;

  @override
  ConsumerState<_SponsorPackSheet> createState() => _SponsorPackSheetState();
}

class _SponsorPackSheetState extends ConsumerState<_SponsorPackSheet> {
  PackSponsorOption? _selected;
  final _selectedZones = <AdPlacement>{...packAdPlacements};
  var _saving = false;
  String? _error;

  Future<void> _save() async {
    final sponsor = _selected;
    if (sponsor == null) {
      setState(() => _error = 'Elige un local / marca.');
      return;
    }
    if (_selectedZones.isEmpty) {
      setState(() => _error = 'Marca al menos una zona.');
      return;
    }
    if ((sponsor.imageUrl ?? '').trim().isEmpty &&
        (sponsor.sponsorLogoUrl ?? '').trim().isEmpty) {
      setState(
        () => _error =
            'Esa marca no tiene imagen todavía. Sube creativo en una pieza y vuelve.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(adsRepositoryProvider);
      final imageUrl = (sponsor.imageUrl ?? '').trim().isNotEmpty
          ? sponsor.imageUrl
          : sponsor.sponsorLogoUrl;
      for (final placement in packAdPlacements) {
        if (!_selectedZones.contains(placement)) continue;
        await repo.saveAd(
          title: sponsor.name,
          description: '',
          sponsorName: sponsor.name,
          buttonText: 'Ver más',
          targetUrl: sponsor.targetUrl,
          placement: placement,
          imageUrl: imageUrl,
          sponsorLogoUrl: sponsor.sponsorLogoUrl,
          forumId: null,
          topicId: null,
          priority: 10,
          maxImpressions: 1000000,
          active: true,
        );
      }
      ref.invalidate(adminAdsProvider);
      ref.invalidate(adminAdStatisticsProvider);
      invalidateForumAds(ref);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${sponsor.name} activado en ${_selectedZones.length} zona'
              '${_selectedZones.length == 1 ? '' : 's'}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar el pack de zonas.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Local en todas las zonas',
                    style: JuntaUi.sectionTitle(color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textMuted,
                ),
              ],
            ),
            Text(
              'Elige el local y marca dónde quieres que salga. '
              'El evento patrocinado se asigna aparte (lleva acto del calendario).',
              style: JuntaUi.caption(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text('1. Local / marca', style: JuntaUi.cardTitle()),
            const SizedBox(height: 8),
            if (widget.sponsors.isEmpty)
              Text(
                'Aún no hay marcas con creativo. Crea primero una pieza con imagen.',
                style: JuntaUi.caption(color: AppColors.textMuted),
              )
            else
              for (final sponsor in widget.sponsors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: _selected?.name == sponsor.name
                        ? AppColors.gold.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () => setState(() => _selected = sponsor),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selected?.name == sponsor.name
                                ? AppColors.gold
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selected?.name == sponsor.name
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: _selected?.name == sponsor.name
                                  ? AppColors.burgundy
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sponsor.name,
                                style: JuntaUi.cardTitle(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            Text('2. Dónde va a salir', style: JuntaUi.cardTitle()),
            const SizedBox(height: 4),
            Text(
              'Desmarca lo que no quieras. Por defecto: todas las zonas actuales.',
              style: JuntaUi.caption(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            for (final placement in packAdPlacements)
              CheckboxListTile(
                value: _selectedZones.contains(placement),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selectedZones.add(placement);
                        } else {
                          _selectedZones.remove(placement);
                        }
                      }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.burgundy,
                title: Text(
                  placementCommercialName(placement),
                  style: JuntaUi.body().copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  placementWhereHint(placement),
                  style: JuntaUi.caption(color: AppColors.textMuted),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: JuntaUi.body(color: AppColors.accentRed)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Activar en ${_selectedZones.length} zona'
                      '${_selectedZones.length == 1 ? '' : 's'}',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

List<PackSponsorOption> packSponsorsFromAds(List<SponsoredAd> ads) {
  final byKey = <String, PackSponsorOption>{};
  for (final ad in ads) {
    final name = ad.sponsorName.trim().isNotEmpty
        ? ad.sponsorName.trim()
        : ad.title.trim();
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    final existing = byKey[key];
    byKey[key] = PackSponsorOption(
      name: existing?.name ?? name,
      targetUrl: (existing?.targetUrl.isNotEmpty ?? false)
          ? existing!.targetUrl
          : ad.targetUrl.trim(),
      imageUrl: (existing?.imageUrl?.trim().isNotEmpty ?? false)
          ? existing!.imageUrl
          : ad.imageUrl,
      sponsorLogoUrl: (existing?.sponsorLogoUrl?.trim().isNotEmpty ?? false)
          ? existing!.sponsorLogoUrl
          : ad.sponsorLogoUrl,
    );
  }
  final list = byKey.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}
