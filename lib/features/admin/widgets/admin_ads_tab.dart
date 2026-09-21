import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/calendar_event.dart';
import '../../ads/ads_provider.dart';
import '../../ads/data/ads_repository.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/utils/ad_priority.dart';
import '../../ads/utils/featured_topic_ads.dart';
import '../../calendar/calendar_provider.dart';
import '../junta_ui.dart';
import 'admin_ads_report.dart';

/// Cupo interno alto: ya no se edita en UI (control = activo + cuota).
const _defaultMaxImpressions = 1000000;

class AdminAdsTab extends ConsumerStatefulWidget {
  const AdminAdsTab({super.key});

  @override
  ConsumerState<AdminAdsTab> createState() => _AdminAdsTabState();
}

class _AdminAdsTabState extends ConsumerState<AdminAdsTab> {
  final _searchController = TextEditingController();
  var _filter = _AdminAdListFilter.all;
  var _onlyOccupied = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SponsoredAd> _filteredAds(List<SponsoredAd> ads) {
    final query = _searchController.text.trim().toLowerCase();
    return ads.where((ad) {
      final matchesFilter = switch (_filter) {
        _AdminAdListFilter.all => true,
        _AdminAdListFilter.active => ad.active,
        _AdminAdListFilter.inactive => !ad.active,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final haystack = [
        ad.title,
        ad.sponsorName,
        ad.targetUrl,
        if (ad.forumId != null) _adForumLabel(ad.forumId!),
        if (ad.topicId != null) featuredTopicAdLabel(ad.topicId!),
        _placementCommercialName(ad.placement),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _assignToSlot({
    AdPlacement? placement,
    String? forumId,
    String? topicId,
  }) {
    final ads = ref.read(adminAdsProvider).asData?.value ?? const <SponsoredAd>[];
    return showPatrocinioAssignSheet(
      context,
      ref,
      catalogAds: ads,
      initialPlacement: placement,
      initialForumId: forumId,
      initialTopicId: topicId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adsAsync = ref.watch(adminAdsProvider);

    return adsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _AdsEmptyState(
        message: 'No se pudieron cargar los patrocinios.',
        onRetry: () => ref.invalidate(adminAdsProvider),
      ),
      data: (ads) {
        final query = _searchController.text.trim();
        final filtered = _filteredAds(ads);
        final activeCount = ads.where((ad) => ad.active).length;
        final searching = query.isNotEmpty || _onlyOccupied || _filter != _AdminAdListFilter.all;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dónde salen los patrocinadores',
                    style: JuntaUi.cardTitle(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Asigna una marca a cada hueco. Con muchas marcas, '
                    'busca por nombre para no perderte en el móvil.',
                    style: JuntaUi.caption(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => showAdStatsSheet(context),
                        icon: const Icon(Icons.insights_outlined, size: 16),
                        label: const Text('Informe'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.burgundy,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showSponsorPackSheet(
                          context,
                          sponsors: packSponsorsFromAds(ads),
                        ),
                        icon: const Icon(Icons.storefront_outlined, size: 16),
                        label: const Text('Todas las zonas'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.burgundy,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _assignToSlot(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nuevo'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.burgundy,
                          foregroundColor: AppColors.textOnDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar patrocinador o foro…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final filter in _AdminAdListFilter.values)
                        ChoiceChip(
                          label: Text(_filterLabel(filter)),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                          visualDensity: VisualDensity.compact,
                        ),
                      FilterChip(
                        label: const Text('Solo ocupados'),
                        selected: _onlyOccupied,
                        onSelected: (value) =>
                            setState(() => _onlyOccupied = value),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        '${ads.length} pieza${ads.length == 1 ? '' : 's'}'
                        ' · $activeCount activa${activeCount == 1 ? '' : 's'}',
                        style: JuntaUi.caption(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _AdsPlacementMap(
                ads: filtered,
                compactEmpty: searching,
                emptyBecauseFilter: filtered.isEmpty && ads.isNotEmpty,
                onClearFilters: () => setState(() {
                  _searchController.clear();
                  _filter = _AdminAdListFilter.all;
                  _onlyOccupied = false;
                }),
                onAssign: (placement, {String? forumId, String? topicId}) =>
                    _assignToSlot(
                  placement: placement,
                  forumId: forumId,
                  topicId: topicId,
                ),
                onEdit: (ad) => _showAdSheet(context, ref, ad: ad),
                onRefresh: () async {
                  ref.invalidate(adminAdsProvider);
                  await ref.read(adminAdsProvider.future);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _filterLabel(_AdminAdListFilter filter) {
    return switch (filter) {
      _AdminAdListFilter.all => 'Todos',
      _AdminAdListFilter.active => 'Activos',
      _AdminAdListFilter.inactive => 'Pausados',
    };
  }
}

/// Mapa visual: cada hueco de la app y quién lo ocupa.
class _AdsPlacementMap extends StatelessWidget {
  const _AdsPlacementMap({
    required this.ads,
    required this.onAssign,
    required this.onEdit,
    required this.onRefresh,
    this.compactEmpty = false,
    this.emptyBecauseFilter = false,
    this.onClearFilters,
  });

  final List<SponsoredAd> ads;
  final void Function(AdPlacement placement, {String? forumId, String? topicId}) onAssign;
  final ValueChanged<SponsoredAd> onEdit;
  final Future<void> Function() onRefresh;
  final bool compactEmpty;
  final bool emptyBecauseFilter;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (emptyBecauseFilter) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            _AdsEmptyState(
              message: 'Ningún patrocinio coincide con la búsqueda.',
              onRetry: onClearFilters,
              retryLabel: 'Quitar filtros',
            ),
          ],
        ),
      );
    }

    final visiblePlacements = _adminAdPlacements.where((placement) {
      if (!compactEmpty) return true;
      return ads.any((ad) => ad.placement == placement);
    }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (compactEmpty && visiblePlacements.isEmpty)
            _AdsEmptyState(
              message: 'Ningún hueco ocupa con estos filtros.',
              onRetry: onClearFilters,
              retryLabel: 'Quitar filtros',
            )
          else
            for (final placement in visiblePlacements)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdsMapPlacementCard(
                  placement: placement,
                  ads: ads.where((ad) => ad.placement == placement).toList(),
                  hideEmptySlots: compactEmpty,
                  onAssign: onAssign,
                  onEdit: onEdit,
                ),
              ),
        ],
      ),
    );
  }
}

class _AdsMapPlacementCard extends StatelessWidget {
  const _AdsMapPlacementCard({
    required this.placement,
    required this.ads,
    required this.onAssign,
    required this.onEdit,
    this.hideEmptySlots = false,
  });

  final AdPlacement placement;
  final List<SponsoredAd> ads;
  final void Function(AdPlacement placement, {String? forumId, String? topicId}) onAssign;
  final ValueChanged<SponsoredAd> onEdit;
  final bool hideEmptySlots;

  bool get _targetsForum =>
      placement == AdPlacement.forumsEvent ||
      placement == AdPlacement.forumsMiddle;

  bool get _targetsTopic => placement == AdPlacement.featuredTopic;

  @override
  Widget build(BuildContext context) {
    final active = ads.where((ad) => ad.active).length;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlacementSectionIcon(placement: placement),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _placementCommercialName(placement),
                        style: JuntaUi.cardTitle(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _placementWhereHint(placement),
                        style: JuntaUi.caption(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$active activo${active == 1 ? '' : 's'}',
                  style: JuntaUi.caption(
                    color: active > 0
                        ? AppColors.burgundyDark
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_targetsForum) ...[
              for (final forumId in _adTargetForumIds)
                if (!hideEmptySlots ||
                    ads.any((ad) => ad.forumId == forumId))
                  _AdsMapSlotRow(
                    label: _adForumLabel(forumId),
                    placement: placement,
                    ads: ads.where((ad) => ad.forumId == forumId).toList(),
                    onAssign: () => onAssign(placement, forumId: forumId),
                    onEdit: onEdit,
                  ),
              if (!hideEmptySlots || ads.any((ad) => ad.forumId == null))
                _AdsMapSlotRow(
                  label: 'Todos los foros',
                  hint: 'También cubre los foros sin marca propia',
                  placement: placement,
                  ads: ads.where((ad) => ad.forumId == null).toList(),
                  onAssign: () => onAssign(placement),
                  onEdit: onEdit,
                ),
            ] else if (_targetsTopic) ...[
              for (final topicId in featuredTopicAdIds)
                if (!hideEmptySlots ||
                    ads.any((ad) => ad.topicId == topicId))
                  _AdsMapSlotRow(
                    label: featuredTopicAdLabel(topicId),
                    placement: placement,
                    ads: ads.where((ad) => ad.topicId == topicId).toList(),
                    onAssign: () => onAssign(placement, topicId: topicId),
                    onEdit: onEdit,
                  ),
              if (!hideEmptySlots || ads.any((ad) => ad.topicId == null))
                _AdsMapSlotRow(
                  label: 'Todos los destacados',
                  hint: 'Cubre Cuaresma, Semana Santa y Glorias',
                  placement: placement,
                  ads: ads.where((ad) => ad.topicId == null).toList(),
                  onAssign: () => onAssign(placement),
                  onEdit: onEdit,
                ),
            ] else
              _AdsMapSlotRow(
                label: 'Espacio global',
                placement: placement,
                ads: ads,
                onAssign: () => onAssign(placement),
                onEdit: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}

class _AdsMapSlotRow extends StatelessWidget {
  const _AdsMapSlotRow({
    required this.label,
    required this.placement,
    required this.ads,
    required this.onAssign,
    required this.onEdit,
    this.hint,
  });

  final String label;
  final AdPlacement placement;
  final String? hint;
  final List<SponsoredAd> ads;
  final VoidCallback onAssign;
  final ValueChanged<SponsoredAd> onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: JuntaUi.caption().copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          hint!,
                          style: JuntaUi.caption(color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onAssign,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(ads.isEmpty ? 'Asignar' : '+ Añadir'),
                ),
              ],
            ),
            if (ads.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  'Sin marca',
                  style: JuntaUi.caption(color: AppColors.textMuted),
                ),
              )
            else
              for (final ad in ads)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onEdit(ad),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ad.active
                                    ? const Color(0xFF2E7D32)
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _adCardHeadline(ad),
                                    style: JuntaUi.body().copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_assetGapLabel(ad, placement) != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _assetGapLabel(ad, placement)!,
                                      style: JuntaUi.caption(
                                        color: AppColors.accentRed,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ad.active ? 'Activo' : 'Pausado',
                              style: JuntaUi.caption(
                                color: ad.active
                                    ? AppColors.burgundyDark
                                    : AppColors.textMuted,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

enum _AdminAdListFilter { all, active, inactive }

class _PlacementSectionIcon extends StatelessWidget {
  const _PlacementSectionIcon({required this.placement});

  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    final icon = switch (placement) {
      AdPlacement.forumsTop => Icons.view_agenda_outlined,
      AdPlacement.forumsEvent => Icons.event_available_outlined,
      AdPlacement.forumsMiddle => Icons.view_list_outlined,
      AdPlacement.featuredTopic => Icons.push_pin_outlined,
      AdPlacement.hermandades => Icons.groups_outlined,
      AdPlacement.calendar => Icons.calendar_month_outlined,
      AdPlacement.search => Icons.travel_explore_outlined,
      _ => Icons.campaign_outlined,
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppColors.goldDark),
    );
  }
}

String _adCardHeadline(SponsoredAd ad) {
  final sponsor = ad.sponsorName.trim();
  if (sponsor.isNotEmpty && sponsor != ad.title.trim()) {
    return sponsor;
  }
  return ad.title;
}

class _AdsEmptyState extends StatelessWidget {
  const _AdsEmptyState({
    required this.message,
    this.onRetry,
    this.retryLabel = 'Reintentar',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: JuntaUi.body(), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showPatrocinioAssignSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<SponsoredAd> catalogAds,
  AdPlacement? initialPlacement,
  String? initialForumId,
  String? initialTopicId,
}) async {
  final seed = await showModalBottomSheet<_SponsorSeed>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _SponsorPickerSheet(
      sponsors: _sponsorCatalogFromAds(catalogAds),
      placement: initialPlacement,
    ),
  );

  if (!context.mounted || seed == null) return;

  final reuse = seed.name.trim().isNotEmpty;
  await _showAdSheet(
    context,
    ref,
    initialPlacement: initialPlacement,
    initialForumId: initialForumId,
    initialTopicId: initialTopicId,
    sponsorSeed: reuse ? seed : null,
  );
}

Future<void> _showAdSheet(
  BuildContext context,
  WidgetRef ref, {
  SponsoredAd? ad,
  AdPlacement? initialPlacement,
  String? initialForumId,
  String? initialTopicId,
  _SponsorSeed? sponsorSeed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _AdFormSheet(
      ad: ad,
      initialPlacement: initialPlacement,
      initialForumId: initialForumId,
      initialTopicId: initialTopicId,
      sponsorSeed: sponsorSeed,
    ),
  );
}

/// Datos reutilizables de una marca ya usada en otras piezas.
class _SponsorSeed {
  const _SponsorSeed({
    required this.name,
    this.targetUrl = '',
    this.imageUrl,
    this.sponsorLogoUrl,
  });

  /// Sentinel: el usuario eligió crear marca nueva (sin reutilizar).
  static const newSponsor = _SponsorSeed(name: '');

  final String name;
  final String targetUrl;
  final String? imageUrl;
  final String? sponsorLogoUrl;

  bool get hasBanner => (imageUrl ?? '').trim().isNotEmpty;
  bool get hasLogo => (sponsorLogoUrl ?? '').trim().isNotEmpty;
}

List<_SponsorSeed> _sponsorCatalogFromAds(List<SponsoredAd> ads) {
  final byKey = <String, _SponsorSeed>{};
  for (final ad in ads) {
    final name = ad.sponsorName.trim().isNotEmpty
        ? ad.sponsorName.trim()
        : ad.title.trim();
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    final existing = byKey[key];
    final candidate = _SponsorSeed(
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
    byKey[key] = candidate;
  }
  final list = byKey.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

String? _assetGapLabel(SponsoredAd ad, AdPlacement placement) {
  if (placement == AdPlacement.forumsEvent) {
    if ((ad.sponsorLogoUrl ?? '').trim().isEmpty) return 'Falta logo';
    return null;
  }
  if ((ad.imageUrl ?? '').trim().isEmpty) return 'Falta imagen';
  return null;
}

String? _seedGapLabel(_SponsorSeed seed, AdPlacement? placement) {
  if (placement == AdPlacement.forumsEvent) {
    if (!seed.hasLogo) return 'Sin logo';
    return null;
  }
  if (placement == null) {
    if (!seed.hasBanner && !seed.hasLogo) return 'Revisar creatividades';
    if (!seed.hasBanner) return 'Sin banner';
    if (!seed.hasLogo) return 'Sin logo';
    return null;
  }
  if (!seed.hasBanner) return 'Sin banner';
  return null;
}

class _SponsorPickerSheet extends StatefulWidget {
  const _SponsorPickerSheet({
    required this.sponsors,
    this.placement,
  });

  final List<_SponsorSeed> sponsors;
  final AdPlacement? placement;

  @override
  State<_SponsorPickerSheet> createState() => _SponsorPickerSheetState();
}

class _SponsorPickerSheetState extends State<_SponsorPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final q = _query.text.trim().toLowerCase();
    final filtered = widget.sponsors
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();

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
                  '¿Qué marca asignas?',
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
            widget.placement == null
                ? 'Elige una marca ya usada o crea una nueva.'
                : 'Hueco: ${_placementCommercialName(widget.placement!)}',
            style: JuntaUi.caption(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (widget.sponsors.length >= 5) ...[
            TextField(
              controller: _query,
              autofocus: widget.sponsors.length >= 8,
              decoration: InputDecoration(
                hintText: 'Buscar patrocinador…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: filtered.isEmpty && widget.sponsors.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Ninguna marca coincide.',
                      style: JuntaUi.caption(color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final sponsor in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => Navigator.pop(context, sponsor),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    _SponsorThumb(seed: sponsor),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sponsor.name,
                                            style: JuntaUi.cardTitle(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_seedGapLabel(
                                                sponsor,
                                                widget.placement,
                                              ) !=
                                              null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              _seedGapLabel(
                                                sponsor,
                                                widget.placement,
                                              )!,
                                              style: JuntaUi.caption(
                                                color: AppColors.accentRed,
                                              ),
                                            ),
                                          ] else
                                            Text(
                                              'Listo para reutilizar',
                                              style: JuntaUi.caption(
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, _SponsorSeed.newSponsor),
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: const Text('Nueva marca'),
          ),
        ],
      ),
    );
  }
}

class _SponsorThumb extends StatelessWidget {
  const _SponsorThumb({required this.seed});

  final _SponsorSeed seed;

  @override
  Widget build(BuildContext context) {
    final url = (seed.sponsorLogoUrl ?? seed.imageUrl)?.trim();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? const Icon(Icons.storefront_outlined, size: 20, color: AppColors.textMuted)
          : CofradeoNetworkImage(
              url: url,
              fit: BoxFit.cover,
              width: 40,
              height: 40,
            ),
    );
  }
}

class _AdFormSheet extends ConsumerStatefulWidget {
  const _AdFormSheet({
    this.ad,
    this.initialPlacement,
    this.initialForumId,
    this.initialTopicId,
    this.sponsorSeed,
  });

  final SponsoredAd? ad;
  final AdPlacement? initialPlacement;
  final String? initialForumId;
  final String? initialTopicId;
  final _SponsorSeed? sponsorSeed;

  @override
  ConsumerState<_AdFormSheet> createState() => _AdFormSheetState();
}

class _AdFormSheetState extends ConsumerState<_AdFormSheet> {
  final _title = TextEditingController();
  final _sponsor = TextEditingController();
  final _targetUrl = TextEditingController();
  final _imageUrl = TextEditingController();
  final _sponsorLogoUrl = TextEditingController();
  final _customPriority = TextEditingController();
  late AdPlacement _placement;
  String? _selectedCalendarEventId;
  String? _selectedForumId;
  String? _selectedTopicId;
  var _priorityValue = adPriorityDefault;
  var _useCustomPriority = false;
  var _active = true;
  var _saving = false;
  String? _error;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _selectedImageExtension;
  String? _selectedImageContentType;
  Uint8List? _selectedLogoBytes;
  String? _selectedLogoName;
  String? _selectedLogoExtension;
  String? _selectedLogoContentType;

  bool get _isEventPlacement => _placement == AdPlacement.forumsEvent;

  bool get _targetsForum =>
      _placement == AdPlacement.forumsEvent ||
      _placement == AdPlacement.forumsMiddle;

  bool get _targetsTopic => _placement == AdPlacement.featuredTopic;

  @override
  void initState() {
    super.initState();
    final ad = widget.ad;
    final seed = widget.sponsorSeed;
    _title.text = ad?.title ?? (seed?.name ?? '');
    _sponsor.text = ad?.sponsorName ?? (seed?.name ?? '');
    _targetUrl.text = ad?.targetUrl ?? (seed?.targetUrl ?? '');
    _imageUrl.text = ad?.imageUrl ?? (seed?.imageUrl ?? '');
    _sponsorLogoUrl.text =
        ad?.sponsorLogoUrl ?? (seed?.sponsorLogoUrl ?? '');
    _selectedCalendarEventId = ad?.calendarEventId;
    _priorityValue = ad?.priority ?? adPriorityDefault;
    _useCustomPriority = adPriorityTierForValue(_priorityValue) == null;
    if (_useCustomPriority) {
      _customPriority.text = '$_priorityValue';
    }
    _placement = ad?.placement ??
        widget.initialPlacement ??
        AdPlacement.forumsTop;
    _selectedForumId = ad?.forumId ?? widget.initialForumId;
    _selectedTopicId = ad?.topicId ?? widget.initialTopicId;
    _active = ad?.active ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _sponsor.dispose();
    _targetUrl.dispose();
    _imageUrl.dispose();
    _sponsorLogoUrl.dispose();
    _customPriority.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async => _pickAsset(isLogo: false);

  Future<void> _pickLogo() async => _pickAsset(isLogo: true);

  Future<void> _pickAsset({required bool isLogo}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'webp', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    final extension = (file.extension ?? '').toLowerCase();
    final contentType = _contentTypeForExtension(extension);
    if (contentType == null) {
      setState(() => _error = 'La imagen debe ser PNG, WebP o JPG.');
      return;
    }
    if (bytes.length > 4 * 1024 * 1024) {
      setState(() => _error = 'La imagen no puede superar 4 MB.');
      return;
    }

    setState(() {
      if (isLogo) {
        _selectedLogoBytes = bytes;
        _selectedLogoName = file.name;
        _selectedLogoExtension = extension;
        _selectedLogoContentType = contentType;
      } else {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _selectedImageExtension = extension;
        _selectedImageContentType = contentType;
      }
      _error = null;
    });
  }

  void _clearImage() {
    setState(() {
      _imageUrl.clear();
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedImageExtension = null;
      _selectedImageContentType = null;
    });
  }

  void _clearLogo() {
    setState(() {
      _sponsorLogoUrl.clear();
      _selectedLogoBytes = null;
      _selectedLogoName = null;
      _selectedLogoExtension = null;
      _selectedLogoContentType = null;
    });
  }

  String? _contentTypeForExtension(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
  }

  String _eventPickerLabel(CalendarEvent event) {
    final date = DateFormat('d MMM', 'es').format(event.date);
    return '$date · ${event.title}';
  }

  Future<void> _save() async {
    final existing = widget.ad;
    late final String title;
    late final String targetUrl;
    String? imageUrl;
    String? sponsorLogoUrl;
    String? calendarEventId;

    if (_isEventPlacement) {
      final eventId = _selectedCalendarEventId?.trim();
      final sponsorName = _sponsor.text.trim();
      if (eventId == null || eventId.isEmpty) {
        setState(() => _error = 'Selecciona un evento del calendario.');
        return;
      }
      if (sponsorName.length < 2) {
        setState(() => _error = 'Indica el patrocinador.');
        return;
      }

      final events = await ref.read(sponsorshipEventPickerProvider.future);
      CalendarEvent? linkedEvent;
      for (final event in events) {
        if (event.id == eventId) {
          linkedEvent = event;
          break;
        }
      }
      linkedEvent ??=
          await ref.read(calendarRepositoryProvider).fetchById(eventId);
      if (linkedEvent == null) {
        setState(() => _error = 'No se encontró el evento seleccionado.');
        return;
      }
      title = linkedEvent.title.trim();

      final rawTarget = _targetUrl.text.trim();
      targetUrl = rawTarget.isEmpty
          ? 'https://cofradeo.app/calendario'
          : normalizeAdTargetUrl(rawTarget);
      calendarEventId = eventId;
      imageUrl = existing?.imageUrl;
      sponsorLogoUrl = _sponsorLogoUrl.text.trim();
    } else {
      title = _title.text.trim();
      targetUrl = normalizeAdTargetUrl(_targetUrl.text.trim());
      final hasImage =
          _selectedImageBytes != null || _imageUrl.text.trim().isNotEmpty;

      if (title.length < 2 || targetUrl.isEmpty) {
        setState(() => _error = 'Título y enlace son obligatorios.');
        return;
      }
      if (!hasImage) {
        setState(() => _error = 'Sube la imagen del banner.');
        return;
      }

      imageUrl = _imageUrl.text.trim();
      sponsorLogoUrl = existing?.sponsorLogoUrl;
      calendarEventId = existing?.calendarEventId;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(adsRepositoryProvider);

      if (_selectedImageBytes != null &&
          _selectedImageExtension != null &&
          _selectedImageContentType != null) {
        imageUrl = await repo.uploadAdAsset(
          bytes: _selectedImageBytes!,
          extension: _selectedImageExtension!,
          contentType: _selectedImageContentType!,
          folder: 'images',
        );
      }

      if (_selectedLogoBytes != null &&
          _selectedLogoExtension != null &&
          _selectedLogoContentType != null) {
        sponsorLogoUrl = await repo.uploadAdAsset(
          bytes: _selectedLogoBytes!,
          extension: _selectedLogoExtension!,
          contentType: _selectedLogoContentType!,
          folder: 'logos',
        );
      }

      await repo.saveAd(
        id: existing?.id,
        title: title,
        description: existing?.description ?? '',
        sponsorName: _isEventPlacement
            ? _sponsor.text.trim()
            : (existing?.sponsorName ?? title),
        buttonText: _isEventPlacement
            ? (existing?.buttonText ?? 'Ver evento')
            : (existing?.buttonText ?? 'Ver más'),
        targetUrl: targetUrl,
        placement: _placement,
        imageUrl: imageUrl,
        sponsorLogoUrl: sponsorLogoUrl,
        calendarEventId: calendarEventId,
        forumId: _targetsForum ? _selectedForumId : null,
        topicId: _targetsTopic ? _selectedTopicId : null,
        priority: _resolvedPriorityValue(),
        maxImpressions: existing?.maxImpressions ?? _defaultMaxImpressions,
        active: _active,
      );
      ref.invalidate(adminAdsProvider);
      ref.invalidate(adminAdStatisticsProvider);
      invalidateForumAds(ref);
      if (mounted) Navigator.pop(context);
    } on AdsRemoteUnavailableException {
      if (mounted) setState(() => _error = 'Supabase no disponible.');
    } on AdAssetTooLargeException {
      if (mounted) setState(() => _error = 'La imagen no puede superar 4 MB.');
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = adSaveErrorMessage(error));
    } catch (error) {
      if (mounted) setState(() => _error = adSaveErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteFromZone() async {
    final existing = widget.ad;
    if (existing == null || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar de esta zona?'),
        content: Text(
          'Se eliminará «${existing.sponsorName.trim().isNotEmpty ? existing.sponsorName : existing.title}» de esta ubicación. '
          'Otras zonas del mismo local no se tocan.\n\n'
          'Pausar (Activo off) también sirve si solo quieres dejarlo parado un tiempo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: AppColors.textOnDark,
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(adsRepositoryProvider).deleteAd(adId: existing.id);
      ref.invalidate(adminAdsProvider);
      ref.invalidate(adminAdStatisticsProvider);
      invalidateForumAds(ref);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patrocinio quitado de esta zona')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = adSaveErrorMessage(error));
    } catch (error) {
      if (mounted) setState(() => _error = adSaveErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _resolvedPriorityValue() {
    if (_useCustomPriority) {
      final parsed = int.tryParse(_customPriority.text.trim());
      if (parsed != null) {
        return parsed.clamp(adPriorityMin, adPriorityMax);
      }
    }
    return _priorityValue.clamp(adPriorityMin, adPriorityMax);
  }

  void _selectPriorityTier(AdPriorityTier tier) {
    setState(() {
      _useCustomPriority = false;
      _priorityValue = tier.value;
      _customPriority.clear();
    });
  }

  void _enableCustomPriority() {
    setState(() {
      _useCustomPriority = true;
      _customPriority.text = '$_priorityValue';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final eventPickerAsync = ref.watch(sponsorshipEventPickerProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.ad == null ? 'Nuevo patrocinio' : 'Editar patrocinio',
                    style: JuntaUi.sectionTitle(color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  color: AppColors.textMuted,
                ),
              ],
            ),
            Text(
              _placementWhereHint(_placement),
              style: JuntaUi.caption(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<AdPlacement>(
              initialValue: _placement,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '¿Dónde sale?',
              ),
              items: _adminAdPlacements
                  .map(
                    (placement) => DropdownMenuItem(
                      value: placement,
                      child: Text(
                        _placementCommercialName(placement),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      if (value != null) {
                        _placement = value;
                        if (!_targetsForum) _selectedForumId = null;
                        if (!_targetsTopic) _selectedTopicId = null;
                      }
                    }),
            ),
            if (_targetsForum) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _selectedForumId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '¿En qué foro?',
                  helperText: '«Todos» = sale en cualquier foro.',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Todos los foros',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final forumId in _adTargetForumIds)
                    DropdownMenuItem<String?>(
                      value: forumId,
                      child: Text(
                        _adForumLabel(forumId),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedForumId = value),
              ),
            ],
            if (_targetsTopic) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _selectedTopicId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '¿En qué tema destacado?',
                  helperText: '«Todos» = Cuaresma, Semana Santa y Glorias.',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Todos los destacados',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final topicId in featuredTopicAdIds)
                    DropdownMenuItem<String?>(
                      value: topicId,
                      child: Text(
                        featuredTopicAdLabel(topicId),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedTopicId = value),
              ),
            ],

            const SizedBox(height: 10),
            if (_isEventPlacement) ...[
              eventPickerAsync.when(
                data: (events) {
                  final selectedId = _selectedCalendarEventId;
                  final hasSelected = selectedId != null &&
                      events.any((event) => event.id == selectedId);
                  return DropdownButtonFormField<String>(
                    initialValue: hasSelected ? selectedId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Evento del calendario',
                    ),
                    items: [
                      for (final event in events)
                        if (event.id != null)
                          DropdownMenuItem(
                            value: event.id,
                            child: Text(
                              _eventPickerLabel(event),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    selectedItemBuilder: (context) => [
                      for (final event in events)
                        if (event.id != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _eventPickerLabel(event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _selectedCalendarEventId = value;
                          }),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(
                  'No se pudieron cargar los eventos.',
                  style: JuntaUi.body(color: AppColors.accentRed),
                ),
              ),
              _AdTextField(controller: _sponsor, label: 'Patrocinador'),
              _AdTextField(
                controller: _targetUrl,
                label: 'Enlace destino (opcional)',
                keyboardType: TextInputType.url,
              ),
              _AdAssetPickerSection(
                title: 'Logo patrocinador',
                helper: 'PNG/WebP con fondo transparente.',
                currentUrl: _sponsorLogoUrl.text,
                selectedName: _selectedLogoName,
                selectedBytes: _selectedLogoBytes,
                previewFit: BoxFit.contain,
                onPick: _saving ? null : _pickLogo,
                onClear: _saving ? null : _clearLogo,
              ),
            ] else ...[
              _AdTextField(controller: _title, label: 'Título'),
              _AdTextField(
                controller: _targetUrl,
                label: 'Enlace destino',
                keyboardType: TextInputType.url,
              ),
              _AdAssetPickerSection(
                title: 'Imagen del anuncio',
                helper: _imageHelperForPlacement(_placement),
                currentUrl: _imageUrl.text,
                selectedName: _selectedImageName,
                selectedBytes: _selectedImageBytes,
                previewFit: BoxFit.cover,
                onPick: _saving ? null : _pickImage,
                onClear: _saving ? null : _clearImage,
              ),
            ],
            _AdPrioritySection(
              placement: _placement,
              forumId: _targetsForum ? _selectedForumId : null,
              topicId: _targetsTopic ? _selectedTopicId : null,
              adId: widget.ad?.id,
              priorityValue: _resolvedPriorityValue(),
              useCustomPriority: _useCustomPriority,
              customPriorityController: _customPriority,
              enabled: !_saving,
              onTierSelected: _selectPriorityTier,
              onCustomSelected: _enableCustomPriority,
              onCustomChanged: () => setState(() {}),
            ),
            SwitchListTile.adaptive(
              value: _active,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _active = value;
                    }),
              title: const Text('Activo'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: JuntaUi.body(color: AppColors.accentRed),
              ),
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
                  : const Text('Guardar patrocinio'),
            ),
            if (widget.ad != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _deleteFromZone,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar de esta zona'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentRed,
                  side: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _adminAdPlacements = [
  AdPlacement.forumsTop,
  AdPlacement.forumsEvent,
  AdPlacement.forumsMiddle,
  AdPlacement.featuredTopic,
  AdPlacement.hermandades,
  AdPlacement.calendar,
  AdPlacement.search,
];

const _adTargetForumIds = [
  'foro-cofradiero',
  'pentagrama-cofrade',
  'martillo-trabajadera',
  'hermandades',
];

String _adForumLabel(String forumId) {
  return switch (forumId) {
    'foro-cofradiero' => 'Círculo Cofrade',
    'pentagrama-cofrade' => 'Pentagrama Cofrade',
    'martillo-trabajadera' => 'Martillo y Trabajadera',
    'hermandades' => 'Hermandades',
    _ => forumId,
  };
}

String _placementCommercialName(AdPlacement placement) {
  return switch (placement) {
    AdPlacement.forumsTop => 'Lista de Foros · banner',
    AdPlacement.forumsEvent => 'Dentro de un foro · Evento patrocinado',
    AdPlacement.forumsMiddle => 'Dentro de un foro · Banner',
    AdPlacement.featuredTopic => 'Tema destacado · banner',
    AdPlacement.hermandades => 'Hermandades · banner',
    AdPlacement.calendar => 'Calendario · banner',
    AdPlacement.search => 'Buscar · banner',
    AdPlacement.profile => 'Perfil',
    AdPlacement.home => 'Inicio',
  };
}

String _placementWhereHint(AdPlacement placement) {
  return switch (placement) {
    AdPlacement.forumsTop =>
      'Sale en la lista principal de foros (encima de la barra inferior).',
    AdPlacement.forumsEvent =>
      'Tarjeta de evento tras los temas fijados, dentro del foro elegido.',
    AdPlacement.forumsMiddle =>
      'Banner «Publicidad» en el listado de temas del foro.',
    AdPlacement.featuredTopic =>
      'Banner dentro de Cuaresma, Semana Santa o Glorias (tema destacado).',
    AdPlacement.hermandades =>
      'Banner en el canal Hermandades (listado por días).',
    AdPlacement.calendar => 'Banner fijo encima de la bottom nav en Calendario.',
    AdPlacement.search => 'Banner en Buscar (pantalla inicial, sin resultados).',
    AdPlacement.profile => 'Reservado · perfil.',
    AdPlacement.home => 'Reservado · inicio.',
  };
}

String _placementLabel(AdPlacement placement) =>
    _placementCommercialName(placement);

String _imageHelperForPlacement(AdPlacement placement) {
  return switch (placement) {
    AdPlacement.forumsTop =>
      'Banner 1200×276 px. Deja libre la esquina inferior derecha para el botón.',
    AdPlacement.calendar ||
    AdPlacement.search ||
    AdPlacement.forumsMiddle ||
    AdPlacement.featuredTopic ||
    AdPlacement.hermandades =>
      'Banner 1200×300 px (ratio 4:1). PNG, WebP o JPG.',
    AdPlacement.forumsEvent ||
    AdPlacement.home ||
    AdPlacement.profile =>
      'Imagen opcional. PNG, WebP o JPG.',
  };
}

class _AdPrioritySection extends ConsumerWidget {
  const _AdPrioritySection({
    required this.placement,
    required this.forumId,
    required this.topicId,
    required this.adId,
    required this.priorityValue,
    required this.useCustomPriority,
    required this.customPriorityController,
    required this.enabled,
    required this.onTierSelected,
    required this.onCustomSelected,
    required this.onCustomChanged,
  });

  final AdPlacement placement;
  final String? forumId;
  final String? topicId;
  final String? adId;
  final int priorityValue;
  final bool useCustomPriority;
  final TextEditingController customPriorityController;
  final bool enabled;
  final ValueChanged<AdPriorityTier> onTierSelected;
  final VoidCallback onCustomSelected;
  final VoidCallback onCustomChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAds = ref.watch(adminAdsProvider).asData?.value ?? const <SponsoredAd>[];
    final draftAd = SponsoredAd(
      id: adId ?? 'draft',
      title: '',
      description: '',
      sponsorName: '',
      buttonText: '',
      targetUrl: 'https://cofradeo.app',
      placement: placement,
      forumId: forumId,
      topicId: topicId,
      priority: priorityValue,
      active: true,
    );
    final competitors = competingAdsForPlacement(allAds, ad: draftAd);
    final share = adSharePercent(draftAd, competitors);
    final tier = adPriorityTierForValue(priorityValue);
    final competitorNames = competitors
        .map((ad) => ad.sponsorName.trim().isNotEmpty ? ad.sponsorName : ad.title)
        .where((name) => name.isNotEmpty)
        .take(3)
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cuota de visibilidad', style: JuntaUi.cardTitle()),
          const SizedBox(height: 4),
          Text(
            'Cada vez que alguien abre esta ubicación, la app sortea entre los '
            'anuncios activos. Cada móvil puede ver uno distinto.',
            style: JuntaUi.caption(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in adPriorityTiers)
                ChoiceChip(
                  label: Text('${option.label} (${option.value})'),
                  selected: !useCustomPriority && priorityValue == option.value,
                  onSelected: enabled
                      ? (_) => onTierSelected(option)
                      : null,
                ),
              ChoiceChip(
                label: const Text('Personalizado'),
                selected: useCustomPriority,
                onSelected: enabled ? (_) => onCustomSelected() : null,
              ),
            ],
          ),
          if (useCustomPriority) ...[
            const SizedBox(height: 8),
            TextField(
              controller: customPriorityController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Peso personalizado ($adPriorityMin-$adPriorityMax)',
                helperText: 'Valor numérico interno del sorteo.',
              ),
              onChanged: (_) => onCustomChanged(),
            ),
          ] else if (tier != null) ...[
            const SizedBox(height: 6),
            Text(tier.hint, style: JuntaUi.caption(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  competitors.isEmpty
                      ? 'Sin competencia en esta ubicación'
                      : 'Probabilidad estimada: ≈${adSharePercentLabel(share)}',
                  style: JuntaUi.body().copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (competitors.isEmpty)
                  Text(
                    'Este anuncio saldría siempre que esté activo y con cupo.',
                    style: JuntaUi.caption(),
                  )
                else ...[
                  Text(
                    'Compite con ${competitors.length} anuncio'
                    '${competitors.length == 1 ? '' : 's'} en '
                    '${_placementLabel(placement)}'
                    '${forumId == null ? '' : ' · ${_adForumLabel(forumId!)}'}.',
                    style: JuntaUi.caption(),
                  ),
                  if (competitorNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      competitorNames.join(', ') +
                          (competitors.length > competitorNames.length
                              ? ' (+${competitors.length - competitorNames.length} más)'
                              : ''),
                      style: JuntaUi.caption(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Ejemplo: prioridad 20 vs 10 ≈ 2× más probabilidad, '
                    'pero no garantiza salir en todos los móviles.',
                    style: JuntaUi.caption(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdAssetPickerSection extends StatelessWidget {
  const _AdAssetPickerSection({
    required this.title,
    required this.helper,
    required this.currentUrl,
    required this.selectedName,
    required this.selectedBytes,
    required this.previewFit,
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final String helper;
  final String currentUrl;
  final String? selectedName;
  final Uint8List? selectedBytes;
  final BoxFit previewFit;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasAsset = selectedBytes != null || currentUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _AdAssetPreview(
            bytes: selectedBytes,
            url: currentUrl,
            fit: previewFit,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JuntaUi.cardTitle(),
                ),
                const SizedBox(height: 3),
                Text(
                  selectedName ??
                      (currentUrl.trim().isNotEmpty
                          ? 'Imagen actual configurada'
                          : helper),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: JuntaUi.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onPick,
                child: Text(hasAsset ? 'Cambiar' : 'Subir'),
              ),
              if (hasAsset)
                TextButton(onPressed: onClear, child: const Text('Quitar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdAssetPreview extends StatelessWidget {
  const _AdAssetPreview({
    required this.bytes,
    required this.url,
    required this.fit,
  });

  final Uint8List? bytes;
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = url.trim();
    Widget child;

    if (bytes != null) {
      child = Image.memory(bytes!, fit: fit);
    } else if (trimmedUrl.startsWith('assets/')) {
      child = Image.asset(
        trimmedUrl,
        fit: fit,
        errorBuilder: (_, _, _) => const _AdAssetFallback(),
      );
    } else if (trimmedUrl.startsWith('http://') ||
        trimmedUrl.startsWith('https://')) {
      child = CofradeoNetworkImage(
        url: trimmedUrl,
        fit: fit,
        width: 74,
        height: 58,
        cacheSize: 74,
        errorWidget: const _AdAssetFallback(),
      );
    } else {
      child = const _AdAssetFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 74,
        height: 58,
        color: AppColors.surface,
        child: child,
      ),
    );
  }
}

class _AdAssetFallback extends StatelessWidget {
  const _AdAssetFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.image_outlined,
      color: AppColors.textMuted.withValues(alpha: 0.75),
    );
  }
}

class _AdTextField extends StatelessWidget {
  const _AdTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
