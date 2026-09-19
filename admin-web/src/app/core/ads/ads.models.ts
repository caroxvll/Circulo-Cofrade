export type AdPlacement =
  | 'home'
  | 'forums_top'
  | 'forums_middle'
  | 'forums_event'
  | 'featured_topic'
  | 'calendar'
  | 'search'
  | 'profile'
  | 'hermandades'
  | 'noticias';

export const ADMIN_AD_PLACEMENTS: AdPlacement[] = [
  'forums_top',
  'forums_event',
  'forums_middle',
  'featured_topic',
  'hermandades',
  'calendar',
  'search',
  'noticias',
];

export const PACK_AD_PLACEMENTS: AdPlacement[] = [
  'forums_top',
  'forums_middle',
  'featured_topic',
  'hermandades',
  'calendar',
  'search',
  'noticias',
];

export const AD_FORUM_IDS = [
  'foro-cofradiero',
  'pentagrama-cofrade',
  'martillo-trabajadera',
  'hermandades',
] as const;

export const FEATURED_TOPIC_IDS = [
  'circulo-cuaresma',
  'circulo-semana-santa',
  'circulo-glorias',
] as const;

export const DEFAULT_MAX_IMPRESSIONS = 1_000_000;

/** Fallback si aún no existe sponsor_settings en Supabase. */
export const DEFAULT_MAX_ACTIVE_COMPANIES = 20;

/** @deprecated Usa AdsService.fetchMaxActiveCompanies(); se mantiene por compat. */
export const MAX_ACTIVE_COMPANIES = DEFAULT_MAX_ACTIVE_COMPANIES;

export interface AdPriorityTier {
  value: number;
  label: string;
  hint: string;
}

/** Pesos de rotación: misma cifra = misma probabilidad en la zona. */
export const AD_PRIORITY_TIERS: AdPriorityTier[] = [
  {
    value: 10,
    label: 'Igualdad',
    hint: 'Misma salida que el resto con Igualdad',
  },
  {
    value: 25,
    label: 'Más visible',
    hint: 'Sale más a menudo que Igualdad',
  },
  {
    value: 50,
    label: 'Premium',
    hint: 'Prioridad clara en la zona',
  },
  {
    value: 100,
    label: 'Máxima',
    hint: 'Máxima exposición relativa',
  },
];

export const AD_PRIORITY_EQUAL = 10;

export interface WaitlistEntry {
  id: string;
  companyName: string;
  contact: string;
  notes: string;
  createdAt: string;
}

export interface SponsoredAd {
  id: string;
  title: string;
  description: string;
  sponsorName: string;
  buttonText: string;
  targetUrl: string;
  placement: AdPlacement;
  imageUrl: string | null;
  sponsorLogoUrl: string | null;
  calendarEventId: string | null;
  forumId: string | null;
  topicId: string | null;
  priority: number;
  maxImpressions: number;
  currentImpressions: number;
  active: boolean;
  createdAt: string;
}

export interface SaveAdInput {
  id?: string;
  title: string;
  description?: string;
  sponsorName: string;
  buttonText?: string;
  targetUrl: string;
  placement: AdPlacement;
  imageUrl?: string | null;
  sponsorLogoUrl?: string | null;
  calendarEventId?: string | null;
  forumId?: string | null;
  topicId?: string | null;
  priority: number;
  maxImpressions?: number;
  active: boolean;
  /** Evita el chequeo de cupo (renombres / igualar zona). */
  skipCupoCheck?: boolean;
}

export interface AdStatisticsRow {
  id: string;
  title: string;
  sponsorName: string;
  placement: AdPlacement | string;
  trackedImpressions: number;
  clicks: number;
  ctr: number;
  currentImpressions: number;
}

export interface PackSponsorOption {
  name: string;
  targetUrl: string;
  imageUrl: string | null;
  sponsorLogoUrl: string | null;
}

/**
 * Placement reservado (no comercial) para la ficha de catálogo de una marca.
 * La empresa se crea aquí sin ocupar una zona visible; luego se coloca en Patrocinios.
 */
export const COMPANY_CATALOG_PLACEMENT: AdPlacement = 'home';

export function isCompanyCatalogPlacement(placement: string): boolean {
  return placement === 'home' || placement === 'profile';
}

/** Marca / empresa agregada desde piezas de publicidad. */
export interface CompanyProfile {
  key: string;
  name: string;
  targetUrl: string;
  /** Banner de zonas (foros, calendario, buscar…). */
  imageUrl: string | null;
  /** Logo para evento patrocinado. */
  sponsorLogoUrl: string | null;
  placements: AdPlacement[];
  adIds: string[];
  activeCount: number;
}

export function placementCommercialName(placement: string): string {
  switch (placement) {
    case 'forums_top':
      return 'Lista de Foros · banner';
    case 'forums_event':
      return 'Dentro de un foro · Evento patrocinado';
    case 'forums_middle':
      return 'Dentro de un foro · Banner';
    case 'featured_topic':
      return 'Tema destacado · banner';
    case 'hermandades':
      return 'Hermandades · banner';
    case 'calendar':
      return 'Calendario · banner';
    case 'search':
      return 'Buscar · banner';
    case 'noticias':
      return 'Noticias · banner';
    case 'profile':
      return 'Perfil';
    case 'home':
      return 'Inicio';
    default:
      return placement;
  }
}

export function placementWhereHint(placement: string): string {
  switch (placement) {
    case 'forums_top':
      return 'Sale en la lista principal de foros (encima de la barra inferior).';
    case 'forums_event':
      return 'Tarjeta de evento tras los temas fijados, dentro del foro elegido.';
    case 'forums_middle':
      return 'Banner «Publicidad» en el listado de temas (todos los foros).';
    case 'featured_topic':
      return 'Banner en Cuaresma, Semana Santa y Glorias.';
    case 'hermandades':
      return 'Banner en el canal Hermandades (listado por días).';
    case 'calendar':
      return 'Banner en la pestaña Calendario.';
    case 'search':
      return 'Banner en Buscar (pantalla inicial, sin resultados).';
    case 'noticias':
      return 'Banner anclado en Noticias (encima de la barra inferior).';
    default:
      return '';
  }
}

export function adForumLabel(forumId: string): string {
  switch (forumId) {
    case 'foro-cofradiero':
      return 'Círculo Cofrade';
    case 'pentagrama-cofrade':
      return 'Pentagrama Cofrade';
    case 'martillo-trabajadera':
      return 'Martillo y Trabajadera';
    case 'hermandades':
      return 'Hermandades';
    default:
      return forumId;
  }
}

export function featuredTopicLabel(topicId: string): string {
  switch (topicId) {
    case 'circulo-cuaresma':
      return 'Cuaresma';
    case 'circulo-semana-santa':
      return 'Semana Santa';
    case 'circulo-glorias':
      return 'Glorias';
    default:
      return topicId;
  }
}

export function adTargetDetail(ad: SponsoredAd): string {
  switch (ad.placement) {
    case 'forums_middle':
    case 'forums_event': {
      const forum = ad.forumId ? adForumLabel(ad.forumId) : 'Todos los foros';
      if (ad.placement === 'forums_event') {
        return ad.calendarEventId
          ? `${forum} · Evento concreto`
          : `${forum} · Todos los eventos (hoy/futuros)`;
      }
      return `Foro: ${forum}`;
    }
    case 'featured_topic':
      return ad.topicId
        ? `Tema: ${featuredTopicLabel(ad.topicId)}`
        : 'Tema: Todos los destacados';
    case 'forums_top':
      return 'Pantalla: lista principal de Foros';
    case 'hermandades':
      return 'Pantalla: canal Hermandades';
    case 'calendar':
      return 'Pantalla: Calendario';
    case 'search':
      return 'Pantalla: Buscar (inicio)';
    case 'noticias':
      return 'Pantalla: Noticias';
    default:
      return '';
  }
}

export function normalizeAdTargetUrl(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return trimmed;
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return `https://${trimmed}`;
}

export function adDisplayName(ad: Pick<SponsoredAd, 'sponsorName' | 'title'>): string {
  const sponsor = ad.sponsorName.trim();
  if (sponsor) return sponsor;
  return ad.title.trim() || 'Sin nombre';
}

/** Evento patrocinado usa logo de empresa; el resto, banner de zona. */
export function adUsesEventLogo(placement: AdPlacement | string): boolean {
  return placement === 'forums_event';
}

/** Creativo que debe verse en el panel según la zona. */
export function adPreviewUrl(
  ad: Pick<SponsoredAd, 'placement' | 'imageUrl' | 'sponsorLogoUrl'>,
): string | null {
  if (adUsesEventLogo(ad.placement)) {
    return ad.sponsorLogoUrl?.trim() || null;
  }
  return ad.imageUrl?.trim() || null;
}

export function adPreviewKind(
  placement: AdPlacement | string,
): 'banner' | 'logo' {
  return adUsesEventLogo(placement) ? 'logo' : 'banner';
}

export function placementShortName(placement: string): string {
  switch (placement) {
    case 'forums_top':
      return 'Foros';
    case 'forums_event':
      return 'Evento';
    case 'forums_middle':
      return 'Dentro foro';
    case 'featured_topic':
      return 'Destacados';
    case 'hermandades':
      return 'Hermandades';
    case 'calendar':
      return 'Calendario';
    case 'search':
      return 'Buscar';
    case 'noticias':
      return 'Noticias';
    default:
      return placementCommercialName(placement);
  }
}

export function companyKeyFromName(name: string): string {
  return name.trim().toLowerCase();
}

export function adPriorityTierForValue(value: number): AdPriorityTier | undefined {
  return AD_PRIORITY_TIERS.find((tier) => tier.value === value);
}

export function adPriorityLabel(priority: number): string {
  return adPriorityTierForValue(priority)?.label ?? `Personalizada (${priority})`;
}

function forumTargetingOverlaps(a: string | null, b: string | null): boolean {
  if (!a || !b) return true;
  return a === b;
}

function topicTargetingOverlaps(a: string | null, b: string | null): boolean {
  if (!a || !b) return true;
  return a === b;
}

export function adIsEligibleForRotation(ad: SponsoredAd): boolean {
  return ad.active && ad.currentImpressions < ad.maxImpressions;
}

/** Competidores en la misma zona (y foro/tema si aplica). */
export function competingAdsForPlacement(
  all: SponsoredAd[],
  ad: Pick<SponsoredAd, 'id' | 'placement' | 'forumId' | 'topicId'>,
): SponsoredAd[] {
  return all.filter((candidate) => {
    if (candidate.id === ad.id) return false;
    if (!adIsEligibleForRotation(candidate)) return false;
    if (candidate.placement !== ad.placement) return false;
    if (!forumTargetingOverlaps(candidate.forumId, ad.forumId)) return false;
    if (!topicTargetingOverlaps(candidate.topicId, ad.topicId)) return false;
    return true;
  });
}

/** Cuota estimada de impresiones ≈ priority / suma de prioridades. */
export function adSharePercent(
  priority: number,
  competitors: SponsoredAd[],
  selfActive = true,
): number | null {
  if (!selfActive) return 0;
  const total =
    priority + competitors.reduce((sum, item) => sum + item.priority, 0);
  if (total <= 0) return null;
  return (priority / total) * 100;
}

export function adSharePercentLabel(share: number | null): string {
  if (share == null) return '—';
  if (share >= 99.95) return '100%';
  if (share < 0.05) return '<1%';
  return `${Math.round(share)}%`;
}

export function adPrioritySummary(
  priority: number,
  sharePercent: number | null,
  competitorCount: number,
): string {
  const tier = adPriorityLabel(priority);
  const share = adSharePercentLabel(sharePercent);
  if (competitorCount === 0) return `${tier} · única activa en la zona`;
  return `${tier} · ≈${share} de las salidas`;
}
