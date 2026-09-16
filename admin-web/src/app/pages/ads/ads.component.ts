import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdsService } from '../../core/ads/ads.service';
import {
  downloadAdsReportExcel,
  downloadAdsReportWord,
  fetchBrandLogoDataUrl,
} from '../../core/ads/ads-report-export';
import {
  ADMIN_AD_PLACEMENTS,
  AD_FORUM_IDS,
  AD_PRIORITY_EQUAL,
  AD_PRIORITY_TIERS,
  AdPlacement,
  AdStatisticsRow,
  DEFAULT_MAX_IMPRESSIONS,
  FEATURED_TOPIC_IDS,
  PACK_AD_PLACEMENTS,
  PackSponsorOption,
  SponsoredAd,
  adDisplayName,
  adForumLabel,
  adPriorityLabel,
  adPrioritySummary,
  adSharePercent,
  adTargetDetail,
  competingAdsForPlacement,
  featuredTopicLabel,
  placementCommercialName,
  placementWhereHint,
} from '../../core/ads/ads.models';

type AdsTab = 'map' | 'report' | 'pack';
type PeriodKind = 'current' | 'previous' | 'custom' | 'all';
type ReportSort = 'impressions' | 'clicks' | 'ctr' | 'company' | 'zone';

interface ReportTableRow {
  id: string;
  sponsorName: string;
  title: string;
  placement: string;
  zoneLabel: string;
  detail: string;
  active: boolean | null;
  impressions: number;
  clicks: number;
  ctr: number;
}

interface ZoneReportSummary {
  placement: AdPlacement | string;
  label: string;
  activePieces: number;
  totalPieces: number;
  impressions: number;
  clicks: number;
  ctr: number;
}

@Component({
  selector: 'app-ads-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './ads.component.html',
  styleUrl: './ads.component.scss',
})
export class AdsPageComponent implements OnInit {
  private readonly adsApi = inject(AdsService);

  readonly tab = signal<AdsTab>('map');
  readonly ads = signal<SponsoredAd[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly saving = signal(false);

  readonly filter = signal<'all' | 'active' | 'paused'>('all');
  search = '';

  readonly editing = signal<SponsoredAd | null>(null);
  readonly showForm = signal(false);

  formTitle = '';
  formSponsor = '';
  formUrl = '';
  formImageUrl = '';
  formLogoUrl = '';
  formPlacement: AdPlacement = 'forums_top';
  formForumId = '';
  formTopicId = '';
  formPriority = AD_PRIORITY_EQUAL;
  formActive = true;

  readonly priorityTiers = AD_PRIORITY_TIERS;
  readonly priorityLabel = adPriorityLabel;

  readonly period = signal<PeriodKind>('current');
  readonly customFrom = signal('');
  readonly customTo = signal('');
  readonly reportSearch = signal('');
  readonly reportZone = signal<'' | AdPlacement | string>('');
  readonly reportSort = signal<ReportSort>('impressions');
  readonly showZeroRows = signal(false);

  readonly stats = signal<AdStatisticsRow[]>([]);
  readonly statsLoading = signal(false);
  readonly statsError = signal<string | null>(null);
  readonly exporting = signal(false);

  readonly packSponsors = signal<PackSponsorOption[]>([]);
  selectedPackName = '';
  selectedZones = new Set<AdPlacement>(PACK_AD_PLACEMENTS);
  readonly packing = signal(false);

  readonly placements = ADMIN_AD_PLACEMENTS;
  readonly packPlacements = PACK_AD_PLACEMENTS;
  readonly forumIds = AD_FORUM_IDS;
  readonly topicIds = FEATURED_TOPIC_IDS;

  readonly commercialName = placementCommercialName;
  readonly whereHint = placementWhereHint;
  readonly forumLabel = adForumLabel;
  readonly topicLabel = featuredTopicLabel;
  readonly targetDetail = adTargetDetail;
  readonly displayName = adDisplayName;

  readonly groupedAds = computed(() => {
    const query = this.search.trim().toLowerCase();
    const filter = this.filter();
    const map = new Map<AdPlacement, SponsoredAd[]>();
    for (const ad of this.ads()) {
      if (filter === 'active' && !ad.active) continue;
      if (filter === 'paused' && ad.active) continue;
      if (query) {
        const hay = `${ad.sponsorName} ${ad.title} ${ad.placement} ${ad.forumId ?? ''} ${ad.topicId ?? ''}`.toLowerCase();
        if (!hay.includes(query)) continue;
      }
      const list = map.get(ad.placement) ?? [];
      list.push(ad);
      map.set(ad.placement, list);
    }
    const ordered = [
      ...ADMIN_AD_PLACEMENTS.filter((p) => map.has(p)),
      ...[...map.keys()].filter((p) => !ADMIN_AD_PLACEMENTS.includes(p)),
    ];
    return ordered.map((placement) => ({
      placement,
      ads: map.get(placement) ?? [],
    }));
  });

  readonly reportRows = computed<ReportTableRow[]>(() => {
    const byId = new Map(this.ads().map((ad) => [ad.id, ad]));
    const query = this.reportSearch().trim().toLowerCase();
    const zone = this.reportZone();
    const includeZero = this.showZeroRows();
    const rows: ReportTableRow[] = [];

    for (const stat of this.stats()) {
      if (!includeZero && stat.trackedImpressions <= 0 && stat.clicks <= 0) continue;
      if (zone && stat.placement !== zone) continue;
      const ad = byId.get(stat.id) ?? null;
      const sponsor = (stat.sponsorName || stat.title || 'Sin nombre').trim();
      if (query) {
        const hay = `${sponsor} ${stat.title} ${placementCommercialName(stat.placement)} ${ad ? adTargetDetail(ad) : ''}`.toLowerCase();
        if (!hay.includes(query)) continue;
      }
      rows.push({
        id: stat.id,
        sponsorName: sponsor,
        title: stat.title,
        placement: stat.placement,
        zoneLabel: placementCommercialName(stat.placement),
        detail: ad ? adTargetDetail(ad) : '',
        active: ad ? ad.active : null,
        impressions: stat.trackedImpressions,
        clicks: stat.clicks,
        ctr: stat.ctr,
      });
    }

    const sort = this.reportSort();
    rows.sort((a, b) => {
      switch (sort) {
        case 'clicks':
          return b.clicks - a.clicks || b.impressions - a.impressions;
        case 'ctr':
          return b.ctr - a.ctr || b.impressions - a.impressions;
        case 'company':
          return a.sponsorName.localeCompare(b.sponsorName, 'es');
        case 'zone':
          return a.zoneLabel.localeCompare(b.zoneLabel, 'es') || b.impressions - a.impressions;
        case 'impressions':
        default:
          return b.impressions - a.impressions || b.clicks - a.clicks;
      }
    });
    return rows;
  });

  readonly reportTotals = computed(() => {
    const rows = this.reportRows();
    const impressions = rows.reduce((sum, row) => sum + row.impressions, 0);
    const clicks = rows.reduce((sum, row) => sum + row.clicks, 0);
    const companies = new Set(rows.map((row) => row.sponsorName.toLowerCase())).size;
    const zones = new Set(rows.map((row) => row.placement)).size;
    const ctr =
      impressions <= 0 ? 0 : Math.round((clicks / impressions) * 10000) / 100;
    return { impressions, clicks, ctr, companies, zones, pieces: rows.length };
  });

  readonly zoneSummaries = computed<ZoneReportSummary[]>(() => {
    const byId = new Map(this.ads().map((ad) => [ad.id, ad]));
    const statsByPlacement = new Map<string, { impressions: number; clicks: number }>();
    for (const stat of this.stats()) {
      const bucket = statsByPlacement.get(stat.placement) ?? {
        impressions: 0,
        clicks: 0,
      };
      bucket.impressions += stat.trackedImpressions;
      bucket.clicks += stat.clicks;
      statsByPlacement.set(stat.placement, bucket);
    }

    const placements = [
      ...ADMIN_AD_PLACEMENTS,
      ...[...statsByPlacement.keys()].filter(
        (p) => !ADMIN_AD_PLACEMENTS.includes(p as AdPlacement),
      ),
    ];

    return placements
      .map((placement) => {
        const pieces = this.ads().filter((ad) => ad.placement === placement);
        const metrics = statsByPlacement.get(placement) ?? {
          impressions: 0,
          clicks: 0,
        };
        const ctr =
          metrics.impressions <= 0
            ? 0
            : Math.round((metrics.clicks / metrics.impressions) * 10000) / 100;
        return {
          placement,
          label: placementCommercialName(placement),
          activePieces: pieces.filter((ad) => ad.active).length,
          totalPieces: pieces.length,
          impressions: metrics.impressions,
          clicks: metrics.clicks,
          ctr,
        };
      })
      .filter((row) => row.totalPieces > 0 || row.impressions > 0 || row.clicks > 0);
  });

  readonly periodLabel = computed(() => {
    const now = new Date();
    switch (this.period()) {
      case 'current':
        return this.monthLabel(now);
      case 'previous':
        return this.monthLabel(new Date(now.getFullYear(), now.getMonth() - 1, 1));
      case 'custom': {
        const from = this.customFrom();
        const to = this.customTo();
        if (!from && !to) return 'Rango personalizado';
        return `${from || '…'} → ${to || '…'}`;
      }
      case 'all':
        return 'Todo el tiempo';
    }
  });

  readonly reportZoneOptions = computed(() => {
    const set = new Set<string>();
    for (const ad of this.ads()) set.add(ad.placement);
    for (const stat of this.stats()) set.add(stat.placement);
    const ordered = [
      ...ADMIN_AD_PLACEMENTS.filter((p) => set.has(p)),
      ...[...set].filter((p) => !ADMIN_AD_PLACEMENTS.includes(p as AdPlacement)),
    ];
    return ordered.map((placement) => ({
      value: placement,
      label: placementCommercialName(placement),
    }));
  });

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const ads = await this.adsApi.fetchAdminAds();
      this.ads.set(ads);
      this.packSponsors.set(this.adsApi.packSponsorsFromAds(ads));
      if (this.tab() === 'report') await this.loadStats();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudieron cargar los anuncios');
    } finally {
      this.loading.set(false);
    }
  }

  setTab(tab: AdsTab): void {
    this.tab.set(tab);
    if (tab === 'report') void this.loadStats();
  }

  openCreate(placement?: AdPlacement): void {
    this.editing.set(null);
    this.formTitle = '';
    this.formSponsor = '';
    this.formUrl = '';
    this.formImageUrl = '';
    this.formLogoUrl = '';
    this.formPlacement = placement ?? 'forums_top';
    this.formForumId = '';
    this.formTopicId = '';
    this.formPriority = AD_PRIORITY_EQUAL;
    this.formActive = true;
    this.showForm.set(true);
  }

  openEdit(ad: SponsoredAd): void {
    this.editing.set(ad);
    this.formTitle = ad.title;
    this.formSponsor = ad.sponsorName || ad.title;
    this.formUrl = ad.targetUrl;
    this.formImageUrl = ad.imageUrl ?? '';
    this.formLogoUrl = ad.sponsorLogoUrl ?? '';
    this.formPlacement = ad.placement;
    this.formForumId = ad.forumId ?? '';
    this.formTopicId = ad.topicId ?? '';
    this.formPriority = ad.priority;
    this.formActive = ad.active;
    this.showForm.set(true);
  }

  closeForm(): void {
    this.showForm.set(false);
    this.editing.set(null);
  }

  needsForum(): boolean {
    return this.formPlacement === 'forums_middle' || this.formPlacement === 'forums_event';
  }

  needsTopic(): boolean {
    return this.formPlacement === 'featured_topic';
  }

  setPriorityTier(value: number): void {
    this.formPriority = value;
  }

  formPriorityHint(): string {
    const draft = {
      id: this.editing()?.id ?? '__draft__',
      placement: this.formPlacement,
      forumId: this.needsForum() ? this.formForumId || null : null,
      topicId: this.needsTopic() ? this.formTopicId || null : null,
    };
    const competitors = competingAdsForPlacement(this.ads(), draft);
    const share = adSharePercent(this.formPriority, competitors, this.formActive);
    return adPrioritySummary(this.formPriority, share, competitors.length);
  }

  async equalizeZone(placement: AdPlacement): Promise<void> {
    if (
      !confirm(
        `¿Igualar la rotación en «${placementCommercialName(placement)}»?\nTodas las piezas activas tendrán la misma probabilidad de salida.`,
      )
    ) {
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      const n = await this.adsApi.equalizePlacement(placement, AD_PRIORITY_EQUAL);
      await this.reload();
      alert(n === 0 ? 'Ya estaban igualadas.' : `Igualadas ${n} pieza(s).`);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo igualar');
    } finally {
      this.saving.set(false);
    }
  }

  async saveForm(): Promise<void> {
    if (this.formTitle.trim().length < 2) {
      this.error.set('El título debe tener al menos 2 caracteres.');
      return;
    }
    if (!this.formUrl.trim()) {
      this.error.set('Indica un enlace destino.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.adsApi.saveAd({
        id: this.editing()?.id,
        title: this.formTitle,
        sponsorName: this.formSponsor || this.formTitle,
        targetUrl: this.formUrl,
        imageUrl: this.formImageUrl,
        sponsorLogoUrl: this.formLogoUrl,
        placement: this.formPlacement,
        forumId: this.needsForum() ? this.formForumId || null : null,
        topicId: this.needsTopic() ? this.formTopicId || null : null,
        calendarEventId: null,
        priority: this.formPriority,
        maxImpressions: this.editing()?.maxImpressions ?? DEFAULT_MAX_IMPRESSIONS,
        active: this.formActive,
        description: this.editing()?.description ?? '',
        buttonText: this.editing()?.buttonText ?? 'Ver más',
      });
      this.closeForm();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar');
    } finally {
      this.saving.set(false);
    }
  }

  async toggleActive(ad: SponsoredAd): Promise<void> {
    this.busyId.set(ad.id);
    try {
      await this.adsApi.setAdActive(ad.id, !ad.active);
      this.ads.update((list) =>
        list.map((item) =>
          item.id === ad.id ? { ...item, active: !ad.active } : item,
        ),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cambiar el estado');
    } finally {
      this.busyId.set(null);
    }
  }

  async removeAd(ad: SponsoredAd): Promise<void> {
    if (!confirm(`¿Quitar «${adDisplayName(ad)}» de esta zona?`)) return;
    this.busyId.set(ad.id);
    try {
      await this.adsApi.deleteAd(ad.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar');
    } finally {
      this.busyId.set(null);
    }
  }

  async onUpload(kind: 'image' | 'logo', event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      const url = await this.adsApi.uploadAdAsset(
        file,
        kind === 'image' ? 'images' : 'logos',
      );
      if (kind === 'image') this.formImageUrl = url;
      else this.formLogoUrl = url;
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo subir');
    } finally {
      this.saving.set(false);
      input.value = '';
    }
  }

  async loadStats(): Promise<void> {
    this.statsLoading.set(true);
    this.statsError.set(null);
    try {
      const range = this.periodRange();
      this.stats.set(await this.adsApi.fetchAdStatistics(range.from, range.to));
    } catch (err) {
      this.statsError.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste ads_statistics_period.sql?`
          : 'No se pudo cargar el informe',
      );
    } finally {
      this.statsLoading.set(false);
    }
  }

  setPeriod(kind: PeriodKind): void {
    this.period.set(kind);
    if (kind === 'custom') {
      if (!this.customFrom() || !this.customTo()) {
        const now = new Date();
        const start = new Date(now.getFullYear(), now.getMonth(), 1);
        const end = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        this.customFrom.set(this.toDateInput(start));
        this.customTo.set(this.toDateInput(end));
      }
    }
    void this.loadStats();
  }

  applyCustomRange(): void {
    this.period.set('custom');
    void this.loadStats();
  }

  setReportSort(sort: ReportSort): void {
    this.reportSort.set(sort);
  }

  formatInt(value: number): string {
    return new Intl.NumberFormat('es-ES').format(value);
  }

  formatCtr(value: number): string {
    return `${value.toLocaleString('es-ES', {
      minimumFractionDigits: value % 1 === 0 ? 0 : 1,
      maximumFractionDigits: 2,
    })}%`;
  }

  copyCsv(): void {
    const periodo = this.periodLabel().replaceAll(',', ' ');
    const lines = [
      'periodo,marca,zona,detalle,estado,impresiones,clics,ctr_porcentaje',
    ];
    for (const row of this.reportRows()) {
      const name = row.sponsorName.replaceAll(',', ' ');
      const zone = row.zoneLabel.replaceAll(',', ' ');
      const detail = row.detail.replaceAll(',', ' ');
      const estado =
        row.active == null ? '' : row.active ? 'activo' : 'pausado';
      lines.push(
        `${periodo},${name},${zone},${detail},${estado},${row.impressions},${row.clicks},${row.ctr}`,
      );
    }
    void navigator.clipboard.writeText(lines.join('\n'));
  }

  async downloadExcel(): Promise<void> {
    if (this.reportRows().length === 0 && this.zoneSummaries().length === 0) return;
    this.exporting.set(true);
    try {
      downloadAdsReportExcel(this.buildExportPayload());
    } finally {
      this.exporting.set(false);
    }
  }

  async downloadWord(): Promise<void> {
    if (this.reportRows().length === 0 && this.zoneSummaries().length === 0) return;
    this.exporting.set(true);
    this.error.set(null);
    try {
      const logoDataUrl = await fetchBrandLogoDataUrl('/logo-mark.png');
      downloadAdsReportWord({
        ...this.buildExportPayload(),
        logoDataUrl,
      });
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo generar el Word',
      );
    } finally {
      this.exporting.set(false);
    }
  }

  private buildExportPayload() {
    return {
      periodLabel: this.periodLabel(),
      generatedAt: new Date(),
      totals: this.reportTotals(),
      zones: this.zoneSummaries().map((zone) => ({
        label: zone.label,
        activePieces: zone.activePieces,
        totalPieces: zone.totalPieces,
        impressions: zone.impressions,
        clicks: zone.clicks,
        ctr: zone.ctr,
      })),
      rows: this.reportRows().map((row) => ({
        sponsorName: row.sponsorName,
        zoneLabel: row.zoneLabel,
        detail: row.detail,
        active: row.active,
        impressions: row.impressions,
        clicks: row.clicks,
        ctr: row.ctr,
      })),
    };
  }

  isZoneSelected(placement: AdPlacement): boolean {
    return this.selectedZones.has(placement);
  }

  toggleZone(placement: AdPlacement): void {
    const next = new Set(this.selectedZones);
    if (next.has(placement)) next.delete(placement);
    else next.add(placement);
    this.selectedZones = next;
  }

  async savePack(): Promise<void> {
    const sponsor = this.packSponsors().find((s) => s.name === this.selectedPackName);
    if (!sponsor) {
      this.error.set('Elige una marca.');
      return;
    }
    if (this.selectedZones.size === 0) {
      this.error.set('Marca al menos una zona.');
      return;
    }
    this.packing.set(true);
    this.error.set(null);
    try {
      const n = await this.adsApi.savePack({
        sponsor,
        zones: [...this.selectedZones],
      });
      alert(`${sponsor.name} activado en ${n} zona${n === 1 ? '' : 's'}.`);
      await this.reload();
      this.tab.set('map');
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar el pack');
    } finally {
      this.packing.set(false);
    }
  }

  private periodRange(): { from: Date | null; to: Date | null } {
    const now = new Date();
    if (this.period() === 'all') return { from: null, to: null };

    if (this.period() === 'custom') {
      const fromRaw = this.customFrom();
      const toRaw = this.customTo();
      const from = fromRaw ? new Date(`${fromRaw}T00:00:00`) : null;
      let to: Date | null = null;
      if (toRaw) {
        to = new Date(`${toRaw}T00:00:00`);
        to.setDate(to.getDate() + 1);
      }
      return { from, to };
    }

    const start =
      this.period() === 'current'
        ? new Date(now.getFullYear(), now.getMonth(), 1)
        : new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const end = new Date(start.getFullYear(), start.getMonth() + 1, 1);
    return { from: start, to: end };
  }

  private monthLabel(date: Date): string {
    const label = date.toLocaleDateString('es-ES', {
      month: 'long',
      year: 'numeric',
    });
    return label.charAt(0).toUpperCase() + label.slice(1);
  }

  private toDateInput(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
}
