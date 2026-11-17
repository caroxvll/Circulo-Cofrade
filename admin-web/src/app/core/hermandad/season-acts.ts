export type SeasonActKind = 'iguala' | 'ensayos' | 'muda' | 'desarma';
export type SeasonActStatus = 'empty' | 'upcoming' | 'done' | 'mixed';

export interface SeasonActEvent {
  id: string;
  title: string;
  startsAt: string;
  eventType: string;
  createdBy?: string | null;
  organizerLabel?: string | null;
}

export interface SeasonActMilestone {
  kind: SeasonActKind;
  label: string;
  status: SeasonActStatus;
  count: number;
  statusLabel: string;
  events: SeasonActEvent[];
}

export interface SeasonActsSnapshot {
  year: number;
  hermandadName: string;
  topicId?: string;
  profileId?: string | null;
  hasAccount: boolean;
  milestones: SeasonActMilestone[];
  filledCount: number;
  totalCount: number;
  isEmpty: boolean;
  isComplete: boolean;
  coverageLabel: string;
}

export const SEASON_ACT_KINDS: ReadonlyArray<{
  kind: SeasonActKind;
  label: string;
  eventTypes: string[];
  publishKindId: string;
}> = [
  { kind: 'iguala', label: 'Igualá', eventTypes: ['iguala'], publishKindId: 'iguala' },
  { kind: 'ensayos', label: 'Ensayos', eventTypes: ['ensayo'], publishKindId: 'ensayo' },
  { kind: 'muda', label: 'Muda', eventTypes: ['muda'], publishKindId: 'muda' },
  { kind: 'desarma', label: 'Desarmá', eventTypes: ['desarma'], publishKindId: 'desarma' },
];

export const SEASON_ACT_DB_TYPES = ['iguala', 'ensayo', 'muda', 'desarma'] as const;

export function currentSeasonActsYear(now = new Date()): number {
  return now.getFullYear();
}

export function seasonActsRange(year: number): { fromIso: string; toIso: string } {
  return {
    fromIso: new Date(Date.UTC(year, 0, 1)).toISOString(),
    toIso: new Date(Date.UTC(year + 1, 0, 1)).toISOString(),
  };
}

function normalizeOrganizerKey(raw: string): string {
  return raw
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/\.+/g, '.');
}

export function eventBelongsToHermandad(
  event: SeasonActEvent,
  hermandadName: string,
  profileId?: string | null,
): boolean {
  if (profileId && event.createdBy === profileId) return true;
  const organizer = (event.organizerLabel ?? '').trim();
  if (!organizer) return false;
  const orgKey = normalizeOrganizerKey(organizer);
  const nameKey = normalizeOrganizerKey(hermandadName);
  if (orgKey.length < 2 || nameKey.length < 2) return false;
  return orgKey === nameKey;
}

function startOfToday(): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

function formatDay(iso: string): string {
  return new Date(iso)
    .toLocaleDateString('es-ES', { day: 'numeric', month: 'short' })
    .replace('.', '');
}

function statusFor(
  kind: SeasonActKind,
  events: SeasonActEvent[],
): SeasonActStatus {
  if (!events.length) return 'empty';
  const today = startOfToday();
  const upcoming = events.filter((e) => new Date(e.startsAt) >= today).length;
  const done = events.length - upcoming;
  if (kind === 'ensayos') {
    if (done > 0 && upcoming > 0) return 'mixed';
    if (upcoming > 0) return 'upcoming';
    return 'done';
  }
  if (upcoming > 0) return 'upcoming';
  return 'done';
}

function statusLabel(
  kind: SeasonActKind,
  status: SeasonActStatus,
  events: SeasonActEvent[],
): string {
  if (status === 'empty') return 'Sin publicar';
  const today = startOfToday();
  const upcoming = events.filter((e) => new Date(e.startsAt) >= today);
  const next = upcoming[0]?.startsAt;
  const last = events[events.length - 1]?.startsAt;

  if (status === 'upcoming') {
    if (!next) return 'Programado';
    if (kind === 'ensayos' && events.length > 1) {
      return `${events.length} · próximo ${formatDay(next)}`;
    }
    return formatDay(next);
  }
  if (status === 'mixed') {
    const done = events.length - upcoming.length;
    if (!next) return `${done} hechos`;
    return `${done} hechos · próximo ${formatDay(next)}`;
  }
  if (kind === 'ensayos' && events.length > 1) {
    return `${events.length} hechos`;
  }
  return last ? `Hecho · ${formatDay(last)}` : 'Hecho';
}

export function buildSeasonActsSnapshot(input: {
  year: number;
  hermandadName: string;
  events: SeasonActEvent[];
  topicId?: string;
  profileId?: string | null;
  hasAccount?: boolean;
}): SeasonActsSnapshot {
  const hasAccount = input.hasAccount ?? true;
  const own = input.events
    .filter((e) =>
      eventBelongsToHermandad(e, input.hermandadName, input.profileId),
    )
    .slice()
    .sort(
      (a, b) =>
        new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime(),
    );

  const milestones: SeasonActMilestone[] = SEASON_ACT_KINDS.map((def) => {
    const matched = own.filter((e) => def.eventTypes.includes(e.eventType));
    const status = statusFor(def.kind, matched);
    return {
      kind: def.kind,
      label: def.label,
      status,
      count: matched.length,
      statusLabel: statusLabel(def.kind, status, matched),
      events: matched,
    };
  });

  const filledCount = milestones.filter((m) => m.status !== 'empty').length;
  const totalCount = milestones.length;
  const isEmpty = filledCount === 0;
  const isComplete = filledCount === totalCount;

  let coverageLabel = `${filledCount}/${totalCount}`;
  if (!hasAccount) coverageLabel = 'Sin cuenta';
  else if (isEmpty) coverageLabel = 'Sin actos';
  else if (isComplete) coverageLabel = 'Completo';

  return {
    year: input.year,
    hermandadName: input.hermandadName,
    topicId: input.topicId,
    profileId: input.profileId,
    hasAccount,
    milestones,
    filledCount,
    totalCount,
    isEmpty,
    isComplete,
    coverageLabel,
  };
}
