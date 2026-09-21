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
  CompanyProfile,
  DEFAULT_MAX_IMPRESSIONS,
  FEATURED_TOPIC_IDS,
  PACK_AD_PLACEMENTS,
  PackSponsorOption,
  SponsoredAd,
  adDisplayName,
  adForumLabel,
  adPreviewKind,
  adPreviewUrl,
  adPriorityLabel,
  adPrioritySummary,
  adSharePercent,
  adTargetDetail,
  adUsesEventLogo,
  competingAdsForPlacement,
  featuredTopicLabel,
  placementCommercialName,
  placementShortName,
  placementWhereHint,
} from '../../core/ads/ads.models';
import { EventsService } from '../../core/events/events.service';
import { CalendarEventRow } from '../../core/events/events.models';

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

interface ZoneBoard {
  placement: AdPlacement;
  label: string;
  shortLabel: string;
  hint: string;
  ads: SponsoredAd[];
  activeCount: number;
  companyNames: string[];
  missingLogoCount: number;
  isEventZone: boolean;
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
  private readonly eventsApi = inject(EventsService);

  readonly tab = signal<AdsTab>('map');
  readonly ads = signal<SponsoredAd[]>([]);
  readonly companies = signal<CompanyProfile[]>([]);
  readonly calendarEvents = signal<CalendarEventRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly saving = signal(false);

  readonly filter = signal<'all' | 'active' | 'paused'>('all');
  readonly focusZone = signal<AdPlacement | ''>('');
  search = '';

  readonly editing = signal<SponsoredAd | null>(null);
  readonly showForm = signal(false);
  /** Si true, la zona viene de «Añadir aquí» y no se elige en el formulario. */
  readonly formZoneLocked = signal(false);
  readonly quickAddingKey = signal<string | null>(null);

  formTitle = '';
  formSponsor = '';
  formUrl = '';
  formImageUrl = '';
  formLogoUrl = '';
  formPlacement: AdPlacement = 'forums_top';
  formForumId = '';
  formTopicId = '';
  formCalendarEventId = '__all__';
  formCompanyKey = '';
  formPriority = AD_PRIORITY_EQUAL;
  formActive = true;

  /** Valor especial: patrocinio sobre cualquier evento hoy/futuro. */
  readonly allEventsValue = '__all__';

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
  readonly shortName = placementShortName;
  readonly whereHint = placementWhereHint;
  readonly forumLabel = adForumLabel;
  readonly topicLabel = featuredTopicLabel;
  readonly targetDetail = adTargetDetail;
  readonly displayName = adDisplayName;
  readonly previewUrl = adPreviewUrl;
  readonly previewKind = adPreviewKind;
  readonly usesEventLogo = adUsesEventLogo;

  /** % estimado de salida frente a competidores activos de la misma zona. */
  shareForAd(ad: SponsoredAd): number | null {
    const competitors = competingAdsForPlacement(this.ads(), ad).filter(
      (item) => item.active,
    );
    return adSharePercent(ad.priority, competitors, ad.active);
  }

  shareLabel(ad: SponsoredAd): string {
    const share = this.shareForAd(ad);
    if (share == null) return '';
    const rounded = Math.round(share);
    return `~${rounded}% salidas`;
  }

  readonly mapOverview = computed(() => {
    const ads = this.ads();
    const active = ads.filter((ad) => ad.active);
    const companies = new Set(active.map((ad) => adDisplayName(ad).toLowerCase()));
    const zones = new Set(active.map((ad) => ad.placement));
    const eventAds = ads.filter((ad) => ad.placement === 'forums_event');
    const missingEventLogo = eventAds.filter((ad) => !ad.sponsorLogoUrl?.trim()).length;
    return {
      activePieces: active.length,
      companies: companies.size,
      zones: zones.size,
      totalZones: ADMIN_AD_PLACEMENTS.length,
      missingEventLogo,
    };
  });

  readonly zoneBoards = computed<ZoneBoard[]>(() => {
    const query = this.search.trim().toLowerCase();
    const filter = this.filter();
    const focus = this.focusZone();

    return ADMIN_AD_PLACEMENTS.filter((placement) => !focus || placement === focus).map(
      (placement) => {
        const ads = this.ads().filter((ad) => {
          if (ad.placement !== placement) return false;
          if (filter === 'active' && !ad.active) return false;
          if (filter === 'paused' && ad.active) return false;
          if (query) {
            const hay =
              `${ad.sponsorName} ${ad.title} ${ad.placement} ${ad.forumId ?? ''} ${ad.topicId ?? ''}`.toLowerCase();
            if (!hay.includes(query)) return false;
          }
          return true;
        });
        const activeAds = ads.filter((ad) => ad.active);
        const companyNames = [
          ...new Set(activeAds.map((ad) => adDisplayName(ad))),
        ].sort((a, b) => a.localeCompare(b, 'es'));
        const missingLogoCount =
          placement === 'forums_event'
            ? ads.filter((ad) => !ad.sponsorLogoUrl?.trim()).length
            : 0;

        return {
          placement,
          label: placementCommercialName(placement),
          shortLabel: placementShortName(placement),
          hint: placementWhereHint(placement),
          ads,
          activeCount: activeAds.length,
          companyNames,
          missingLogoCount,
          isEventZone: placement === 'forums_event',
        };
      },
    );
  });

  /** Empresas para meter en la zona del formulario (un clic). */
  readonly formCompanyChoices = computed(() => {
    const placement = this.formPlacement;
    const inZone = new Set(
      this.ads()
        .filter((ad) => ad.placement === placement)
        .map((ad) => adDisplayName(ad).toLowerCase()),
    );
    return this.companies().map((company) => {
      const needsLogo = adUsesEventLogo(placement);
      const hasAsset = needsLogo
        ? !!company.sponsorLogoUrl?.trim()
        : !!company.imageUrl?.trim();
      const alreadyInZone = inZone.has(company.key);
      return {
        company,
        alreadyInZone,
        hasAsset,
        needsLogo,
        /** Banner zones: un clic guarda. Eventos: un clic rellena (falta calendario). */
        canOneClickPlace: hasAsset && !alreadyInZone && !needsLogo,
      };
    });
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
      const [ads, events] = await Promise.all([
        this.adsApi.fetchAdminAds(),
        this.eventsApi.listEvents({ status: 'published', range: 'upcoming', limit: 200 }),
      ]);
      this.ads.set(ads);
      this.companies.set(this.adsApi.listCompanies(ads));
      this.packSponsors.set(this.adsApi.packSponsorsFromAds(ads));
      this.calendarEvents.set(events);
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

  setFocusZone(placement: AdPlacement | ''): void {
    this.focusZone.set(this.focusZone() === placement ? '' : placement);
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
    this.formCalendarEventId = this.allEventsValue;
    this.formCompanyKey = '';
    this.formPriority = AD_PRIORITY_EQUAL;
    this.formActive = true;
    this.formZoneLocked.set(!!placement);
    this.quickAddingKey.set(null);
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
    this.formCalendarEventId = ad.calendarEventId?.trim()
      ? ad.calendarEventId
      : this.allEventsValue;
    this.formCompanyKey =
      this.companies().find(
        (c) => c.key === adDisplayName(ad).toLowerCase(),
      )?.key ?? '';
    this.formPriority = ad.priority;
    this.formActive = ad.active;
    this.formZoneLocked.set(true);
    this.quickAddingKey.set(null);
    this.showForm.set(true);
  }

  closeForm(): void {
    this.showForm.set(false);
    this.editing.set(null);
    this.formZoneLocked.set(false);
    this.quickAddingKey.set(null);
  }

  needsForum(): boolean {
    return this.formPlacement === 'forums_middle' || this.formPlacement === 'forums_event';
  }

  needsTopic(): boolean {
    return this.formPlacement === 'featured_topic';
  }

  needsEvent(): boolean {
    return this.formPlacement === 'forums_event';
  }

  formIsEventZone(): boolean {
    return adUsesEventLogo(this.formPlacement);
  }

  onPlacementChange(placement: AdPlacement): void {
    if (this.formZoneLocked()) return;
    this.formPlacement = placement;
    if (!this.needsForum()) this.formForumId = '';
    if (!this.needsTopic()) this.formTopicId = '';
    if (!this.needsEvent()) this.formCalendarEventId = this.allEventsValue;
    this.applyCompanyAssets(false);
  }

  onCompanyPick(key: string): void {
    this.formCompanyKey = key;
    if (!key) return;
    const company = this.companies().find((c) => c.key === key);
    if (!company) return;
    this.formSponsor = company.name;
    this.formTitle = company.name;
    if (company.targetUrl) this.formUrl = company.targetUrl;
    this.applyCompanyAssets(true);
  }

  /**
   * Un clic: mete la empresa en la zona actual si tiene creativo.
   * En eventos patrocinados solo rellena y pide el evento del calendario.
   */
  async quickPlaceCompany(company: CompanyProfile): Promise<void> {
    const placement = this.formPlacement;
    const already = this.ads().some(
      (ad) =>
        ad.placement === placement &&
        adDisplayName(ad).toLowerCase() === company.key,
    );
    if (already) {
      this.error.set(`${company.name} ya está en esta zona.`);
      return;
    }

    this.onCompanyPick(company.key);

    if (adUsesEventLogo(placement)) {
      if (!company.sponsorLogoUrl?.trim()) {
        this.error.set(
          `${company.name} no tiene logo de eventos. Súbelo en Empresas.`,
        );
        return;
      }
      // Hace falta elegir evento: dejamos el formulario relleno.
      this.error.set(null);
      return;
    }

    if (!company.imageUrl?.trim()) {
      this.error.set(
        `${company.name} no tiene banner. Súbelo en Empresas o en el formulario.`,
      );
      return;
    }

    this.quickAddingKey.set(company.key);
    this.error.set(null);
    this.saving.set(true);
    try {
      await this.adsApi.saveAd({
        title: company.name,
        sponsorName: company.name,
        targetUrl: company.targetUrl || 'https://',
        imageUrl: company.imageUrl,
        sponsorLogoUrl: company.sponsorLogoUrl,
        placement,
        forumId: null,
        topicId: this.needsTopic() ? this.formTopicId || null : null,
        calendarEventId: null,
        priority: AD_PRIORITY_EQUAL,
        maxImpressions: DEFAULT_MAX_IMPRESSIONS,
        active: true,
        description: '',
        buttonText: 'Ver más',
      });
      this.closeForm();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo añadir');
    } finally {
      this.saving.set(false);
      this.quickAddingKey.set(null);
    }
  }

  /** Rellena banner/logo desde la ficha de empresa. */
  applyCompanyAssets(force: boolean): void {
    const key =
      this.formCompanyKey ||
      this.formSponsor.trim().toLowerCase() ||
      this.formTitle.trim().toLowerCase();
    if (!key) return;
    const company = this.companies().find((c) => c.key === key);
    if (!company) return;

    if (this.formIsEventZone()) {
      if ((force || !this.formLogoUrl.trim()) && company.sponsorLogoUrl) {
        this.formLogoUrl = company.sponsorLogoUrl;
      }
    } else if ((force || !this.formImageUrl.trim()) && company.imageUrl) {
      this.formImageUrl = company.imageUrl;
    }
  }

  eventLabel(eventId: string | null | undefined): string {
    if (!eventId?.trim()) return 'Todos los eventos (hoy y futuros)';
    const event = this.calendarEvents().find((e) => e.id === eventId);
    if (!event) return 'Evento vinculado';
    return this.formatEventOption(event);
  }

  formatEventOption(event: CalendarEventRow): string {
    const when = new Date(event.startsAt).toLocaleString('es-ES', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
    return `${event.title} · ${when}`;
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
        `¿Igualar la rotación en «${placementCommercialName(placement)}»?\n\n` +
          `Todas las piezas ACTIVAS de esta zona pasarán a «Igualdad» (~mismo %).\n` +
          `Si D'arte está en Máxima, perderá esa ventaja hasta que la vuelvas a subir.`,
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
    if (this.needsEvent() && !this.formLogoUrl.trim()) {
      this.error.set(
        'Los eventos patrocinados necesitan el logo de eventos de la empresa. Súbelo o edítalo en Empresas.',
      );
      return;
    }
    if (!this.needsEvent() && !this.formImageUrl.trim()) {
      this.error.set('Sube el banner de la zona (creativo horizontal).');
      return;
    }

    this.applyCompanyAssets(false);

    const calendarEventId = this.needsEvent()
      ? this.formCalendarEventId.trim() === this.allEventsValue ||
        !this.formCalendarEventId.trim()
        ? null
        : this.formCalendarEventId.trim()
      : null;

    this.saving.set(true);
    this.error.set(null);
    try {
      await this.adsApi.saveAd({
        id: this.editing()?.id,
        title: this.formTitle,
        sponsorName: this.formSponsor || this.formTitle,
        targetUrl: this.formUrl,
        imageUrl: this.needsEvent()
          ? this.formImageUrl.trim() || this.editing()?.imageUrl || null
          : this.formImageUrl,
        sponsorLogoUrl: this.formLogoUrl,
        placement: this.formPlacement,
        forumId: this.needsForum() ? this.formForumId || null : null,
        topicId: this.needsTopic() ? this.formTopicId || null : null,
        calendarEventId,
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
