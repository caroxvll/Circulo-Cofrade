import { addDays, easterSunday } from '../season/season.models';

export type SeasonActKind = 'iguala' | 'ensayos' | 'muda' | 'desarma';
export type SeasonActStatus = 'empty' | 'upcoming' | 'done' | 'mixed';

export type SeasonPaso = 'ambos' | 'cristo' | 'cristo2' | 'virgen';
export type HermandadPasosLayout =
  | 'cristo'
  | 'virgen'
  | 'cristo_virgen'
  | 'dos_cristos_virgen';
export type MudaRetranqueoMode = 'with_retranqueo' | 'split' | 'muda_only';

export interface HermandadSeasonProfile {
  pasosLayout: HermandadPasosLayout;
  igualaSplit: boolean;
  ensayoSplit: boolean;
  ensayoCount: number;
  mudaMode: MudaRetranqueoMode;
}

export const DEFAULT_SEASON_PROFILE: HermandadSeasonProfile = {
  pasosLayout: 'cristo_virgen',
  igualaSplit: false,
  ensayoSplit: false,
  ensayoCount: 1,
  mudaMode: 'muda_only',
};

export function parseSeasonPaso(raw: unknown): SeasonPaso {
  const value = String(raw ?? '');
  if (value === 'cristo' || value === 'cristo2' || value === 'virgen') return value;
  return 'ambos';
}

export function eventPasoChoices(
  layout: HermandadPasosLayout,
): ReadonlyArray<{ id: SeasonPaso; label: string }> {
  if (layout === 'cristo') return [{ id: 'cristo', label: 'Cristo' }];
  if (layout === 'virgen') return [{ id: 'virgen', label: 'Virgen' }];
  if (layout === 'dos_cristos_virgen') {
    return [
      { id: 'cristo', label: 'Cristo 1' },
      { id: 'cristo2', label: 'Cristo 2' },
      { id: 'virgen', label: 'Virgen' },
    ];
  }
  return [
    { id: 'ambos', label: 'Ambos' },
    { id: 'cristo', label: 'Cristo' },
    { id: 'virgen', label: 'Virgen' },
  ];
}

export function parsePasosLayout(raw: unknown): HermandadPasosLayout {
  const value = String(raw ?? '');
  if (value === 'cristo' || value === 'virgen' || value === 'dos_cristos_virgen') {
    return value;
  }
  return 'cristo_virgen';
}

export function parseSeasonProfile(
  row: Record<string, unknown> | null | undefined,
): HermandadSeasonProfile {
  if (!row) return { ...DEFAULT_SEASON_PROFILE };
  const mode = String(row['muda_mode'] ?? 'muda_only');
  return {
    pasosLayout: parsePasosLayout(row['pasos_layout']),
    igualaSplit: row['iguala_split'] === true,
    ensayoSplit: row['ensayo_split'] === true,
    ensayoCount: Number(row['ensayo_count'] ?? 1) || 1,
    mudaMode:
      mode === 'with_retranqueo' || mode === 'split' ? mode : 'muda_only',
  };
}

function trackedPasos(layout: HermandadPasosLayout): SeasonPaso[] {
  if (layout === 'cristo') return ['cristo'];
  if (layout === 'virgen') return ['virgen'];
  if (layout === 'dos_cristos_virgen') return ['cristo', 'cristo2', 'virgen'];
  return ['cristo', 'virgen'];
}

function slotLabel(layout: HermandadPasosLayout, paso: SeasonPaso): string {
  if (paso === 'cristo2') return 'Cristo 2';
  if (paso === 'virgen') return 'Virgen';
  if (paso === 'ambos') return 'Ambos';
  return layout === 'dos_cristos_virgen' ? 'Cristo 1' : 'Cristo';
}

function splitsIguala(profile: HermandadSeasonProfile): boolean {
  return (
    profile.pasosLayout === 'dos_cristos_virgen' ||
    (profile.pasosLayout === 'cristo_virgen' && profile.igualaSplit)
  );
}

function splitsEnsayo(profile: HermandadSeasonProfile): boolean {
  return (
    profile.pasosLayout === 'dos_cristos_virgen' ||
    (profile.pasosLayout === 'cristo_virgen' && profile.ensayoSplit)
  );
}

export interface SeasonActEvent {
  id: string;
  title: string;
  startsAt: string;
  eventType: string;
  createdBy?: string | null;
  organizerLabel?: string | null;
  hermandadTopicId?: string | null;
  paso?: SeasonPaso;
  seasonN?: number | null;
  withRetranqueo?: boolean;
}

export interface SeasonPasoSlot {
  label: string;
  filled: boolean;
  hint?: string | null;
}

export type SeasonActPasoFilter =
  | 'iguala_cristo'
  | 'iguala_cristo2'
  | 'iguala_virgen'
  | 'iguala_ambas'
  | 'ensayo_cristo'
  | 'ensayo_cristo2'
  | 'ensayo_virgen';

export const SEASON_ACT_PASO_FILTERS: ReadonlyArray<{
  id: SeasonActPasoFilter;
  label: string;
}> = [
  { id: 'iguala_cristo', label: 'Igualá Cristo' },
  { id: 'iguala_cristo2', label: 'Igualá Cristo 2' },
  { id: 'iguala_virgen', label: 'Igualá Virgen' },
  { id: 'iguala_ambas', label: 'Igualá ambas' },
  { id: 'ensayo_cristo', label: 'Ensayos Cristo' },
  { id: 'ensayo_cristo2', label: 'Ensayos Cristo 2' },
  { id: 'ensayo_virgen', label: 'Ensayos Virgen' },
];

export interface SeasonActMilestone {
  kind: SeasonActKind;
  label: string;
  status: SeasonActStatus;
  count: number;
  filledSlots: number;
  requiredSlots: number;
  statusLabel: string;
  events: SeasonActEvent[];
  pasoSlots: SeasonPasoSlot[];
}

export interface SeasonActsSnapshot {
  year: number;
  hermandadName: string;
  topicId?: string;
  profileId?: string | null;
  processionDay?: string | null;
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
  { kind: 'muda', label: 'Muda', eventTypes: ['muda', 'retranqueo'], publishKindId: 'muda' },
  { kind: 'desarma', label: 'Desarmá', eventTypes: ['desarma'], publishKindId: 'desarma' },
];

export const SEASON_ACT_DB_TYPES = [
  'iguala',
  'ensayo',
  'muda',
  'retranqueo',
  'desarma',
] as const;

function coversPaso(eventPaso: SeasonPaso | undefined, needed: SeasonPaso): boolean {
  const paso = eventPaso ?? 'ambos';
  if (needed === 'ambos') return true;
  if (paso === needed) return true;
  if (paso === 'ambos') return needed === 'cristo' || needed === 'virgen';
  return false;
}

function ensayoFilled(events: SeasonActEvent[], n: number): number {
  if (!events.length) return 0;
  const numbered = new Set(
    events
      .map((e) => e.seasonN)
      .filter((v): v is number => typeof v === 'number' && v > 0),
  );
  if (!numbered.size) return Math.min(n, events.length);
  return Math.min(n, numbered.size);
}

function mudaLabel(mode: MudaRetranqueoMode): string {
  if (mode === 'with_retranqueo') return 'Muda+retr.';
  if (mode === 'split') return 'Muda / retr.';
  return 'Muda';
}

const SEASON_ACTS_ROLL_DAYS_AFTER_EASTER = 90;

export function currentSeasonActsYear(now = new Date()): number {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12);
  const easter = easterSunday(today.getFullYear());
  const roll = addDays(easter, SEASON_ACTS_ROLL_DAYS_AFTER_EASTER);
  if (today.getTime() >= roll.getTime()) return today.getFullYear() + 1;
  return today.getFullYear();
}

export function seasonActsRange(year: number): { fromIso: string; toIso: string } {
  return {
    fromIso: new Date(Date.UTC(year - 1, 8, 1)).toISOString(),
    toIso: new Date(Date.UTC(year, 8, 1)).toISOString(),
  };
}

function normalizeOrganizerKey(raw: string): string {
  return raw
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/\.+/g, '.');
}

function foldOrganizer(raw: string): string {
  return raw
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

function canonicalOrganizer(raw: string): string {
  let value = foldOrganizer(normalizeOrganizerKey(raw));
  const prefixes = [
    'real ',
    'ilustre ',
    'pontificia ',
    'venerable ',
    'sacramental ',
    'hdad. ',
    'hdad ',
    'hermandad de la ',
    'hermandad de las ',
    'hermandad del ',
    'hermandad de los ',
    'hermandad de ',
    'hermandad ',
    'de la ',
    'de las ',
    'de los ',
    'del ',
    'de ',
    'la ',
    'el ',
    'las ',
    'los ',
  ];
  let changed = true;
  while (changed) {
    changed = false;
    for (const prefix of prefixes) {
      if (value.startsWith(prefix)) {
        value = value.slice(prefix.length).trimStart();
        changed = true;
      }
    }
  }
  return value;
}

export function organizerMatchScore(
  organizer: string,
  hermandadName: string,
): number {
  const orgKey = normalizeOrganizerKey(organizer);
  const nameKey = normalizeOrganizerKey(hermandadName);
  if (orgKey.length < 2 || nameKey.length < 2) return 0;
  if (orgKey === nameKey) return 100;
  const orgCanon = canonicalOrganizer(organizer);
  const nameCanon = canonicalOrganizer(hermandadName);
  if (orgCanon.length < 3 || nameCanon.length < 3) return 0;
  if (orgCanon === nameCanon) return 90;
  const shorter = orgCanon.length <= nameCanon.length ? orgCanon : nameCanon;
  const longer = orgCanon.length > nameCanon.length ? orgCanon : nameCanon;
  if (shorter.length >= 6 && longer.includes(shorter)) {
    return 40 + Math.min(40, shorter.length * 2);
  }
  return 0;
}

export function organizerMatchesHermandadName(
  organizer: string,
  hermandadName: string,
): boolean {
  return organizerMatchScore(organizer, hermandadName) > 0;
}

export function eventBelongsToHermandad(
  event: SeasonActEvent,
  hermandadName: string,
  profileId?: string | null,
  hermandadTopicId?: string | null,
): boolean {
  const topicId = hermandadTopicId?.trim();
  const linked = event.hermandadTopicId?.trim();
  if (topicId && linked && topicId === linked) return true;
  if (profileId && event.createdBy === profileId) return true;
  const organizer = (event.organizerLabel ?? '').trim();
  if (!organizer) return false;
  return organizerMatchesHermandadName(organizer, hermandadName);
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

function slotsFor(
  kind: SeasonActKind,
  events: SeasonActEvent[],
  profile: HermandadSeasonProfile,
): { filled: number; required: number; detail: string | null } {
  if (kind === 'iguala') {
    if (!splitsIguala(profile)) {
      const tracked = trackedPasos(profile.pasosLayout);
      const hits = events.filter((e) =>
        tracked.some((paso) => coversPaso(e.paso, paso)),
      );
      return { filled: hits.length ? 1 : 0, required: 1, detail: null };
    }
    const tracked = trackedPasos(profile.pasosLayout);
    let filled = 0;
    const missing: string[] = [];
    for (const paso of tracked) {
      if (events.some((e) => coversPaso(e.paso, paso))) filled += 1;
      else missing.push(slotLabel(profile.pasosLayout, paso));
    }
    return {
      filled,
      required: tracked.length,
      detail: missing.length ? missing.map((name) => `falta ${name}`).join(' · ') : null,
    };
  }
  if (kind === 'ensayos') {
    const n = Math.min(12, Math.max(1, profile.ensayoCount));
    if (!splitsEnsayo(profile)) {
      const tracked = trackedPasos(profile.pasosLayout);
      const ofPaso = events.filter((e) =>
        tracked.some((paso) => coversPaso(e.paso, paso)),
      );
      const filled = ensayoFilled(ofPaso, n);
      return {
        filled,
        required: n,
        detail: n > 1 ? `${filled}/${n} ensayos` : null,
      };
    }
    const tracked = trackedPasos(profile.pasosLayout);
    let filled = 0;
    const bits: string[] = [];
    for (const paso of tracked) {
      const count = ensayoFilled(
        events.filter((e) => coversPaso(e.paso, paso)),
        n,
      );
      filled += count;
      bits.push(`${slotLabel(profile.pasosLayout, paso)} ${count}/${n}`);
    }
    return {
      filled,
      required: n * tracked.length,
      detail: bits.join(' · '),
    };
  }
  if (kind === 'muda') {
    const mudas = events.filter((e) => e.eventType === 'muda');
    const retrs = events.filter((e) => e.eventType === 'retranqueo');
    if (profile.mudaMode === 'muda_only') {
      return { filled: mudas.length ? 1 : 0, required: 1, detail: null };
    }
    if (profile.mudaMode === 'with_retranqueo') {
      const combined = mudas.some((e) => e.withRetranqueo);
      const sameDay = mudas.some((m) =>
        retrs.some(
          (r) =>
            new Date(m.startsAt).toDateString() ===
            new Date(r.startsAt).toDateString(),
        ),
      );
      if (combined || sameDay) {
        return { filled: 1, required: 1, detail: 'Muda y retranqueo' };
      }
      if (mudas.length) return { filled: 0, required: 1, detail: 'Muda · falta retranqueo' };
      if (retrs.length) return { filled: 0, required: 1, detail: 'Retranqueo · falta muda' };
      return { filled: 0, required: 1, detail: null };
    }
    const hasMuda = mudas.length > 0;
    const hasRetr = retrs.length > 0;
    return {
      filled: (hasMuda ? 1 : 0) + (hasRetr ? 1 : 0),
      required: 2,
      detail:
        hasMuda && hasRetr
          ? null
          : `${hasMuda ? 'Muda' : 'falta muda'} · ${hasRetr ? 'Retranqueo' : 'falta retranqueo'}`,
    };
  }
  return { filled: events.length ? 1 : 0, required: 1, detail: null };
}

function pasoSlotsFor(
  kind: SeasonActKind,
  events: SeasonActEvent[],
  profile: HermandadSeasonProfile,
): SeasonPasoSlot[] {
  const tracked = trackedPasos(profile.pasosLayout);
  if (kind === 'iguala') {
    return tracked.map((paso) => ({
      label: slotLabel(profile.pasosLayout, paso),
      filled: events.some((e) => coversPaso(e.paso, paso)),
    }));
  }
  if (kind === 'ensayos') {
    const n = Math.min(12, Math.max(1, profile.ensayoCount));
    const showHint = splitsEnsayo(profile) || n > 1;
    return tracked.map((paso) => {
      const count = ensayoFilled(
        events.filter((e) => coversPaso(e.paso, paso)),
        n,
      );
      return {
        label: slotLabel(profile.pasosLayout, paso),
        filled: count > 0,
        hint: showHint ? `${count}/${n}` : null,
      };
    });
  }
  return [];
}

function hasPasoFilled(
  row: SeasonActsSnapshot,
  kind: SeasonActKind,
  pasoLabel: string,
): boolean {
  const milestone = row.milestones.find((m) => m.kind === kind);
  return (
    milestone?.pasoSlots.some(
      (s) =>
        s.filled &&
        (s.label === pasoLabel || (pasoLabel === 'Cristo' && s.label === 'Cristo 1')),
    ) === true
  );
}

export function eventsForPasoSlot(
  events: SeasonActEvent[],
  slot: SeasonPasoSlot,
): SeasonActEvent[] {
  if (slot.label === 'Cristo' || slot.label === 'Cristo 1') {
    return events.filter((e) => coversPaso(e.paso, 'cristo'));
  }
  if (slot.label === 'Cristo 2') {
    return events.filter((e) => coversPaso(e.paso, 'cristo2'));
  }
  if (slot.label === 'Virgen') {
    return events.filter((e) => coversPaso(e.paso, 'virgen'));
  }
  return events;
}

export function matchesPasoFilter(
  row: SeasonActsSnapshot,
  filter: SeasonActPasoFilter | null,
): boolean {
  if (!filter) return true;
  if (filter === 'iguala_cristo') return hasPasoFilled(row, 'iguala', 'Cristo');
  if (filter === 'iguala_cristo2') return hasPasoFilled(row, 'iguala', 'Cristo 2');
  if (filter === 'iguala_virgen') return hasPasoFilled(row, 'iguala', 'Virgen');
  if (filter === 'iguala_ambas') {
    return (
      hasPasoFilled(row, 'iguala', 'Cristo') &&
      hasPasoFilled(row, 'iguala', 'Virgen')
    );
  }
  if (filter === 'ensayo_cristo') return hasPasoFilled(row, 'ensayos', 'Cristo');
  if (filter === 'ensayo_cristo2') return hasPasoFilled(row, 'ensayos', 'Cristo 2');
  if (filter === 'ensayo_virgen') return hasPasoFilled(row, 'ensayos', 'Virgen');
  return true;
}

function foldQuery(raw: string): string {
  return raw
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

export function filterSeasonActsSnapshots(
  rows: SeasonActsSnapshot[],
  query: string,
  processionDay: string | null,
  pasoFilter: SeasonActPasoFilter | null = null,
): SeasonActsSnapshot[] {
  const q = foldQuery(query);
  return rows.filter((row) => {
    if (processionDay && row.processionDay !== processionDay) return false;
    if (!matchesPasoFilter(row, pasoFilter)) return false;
    if (!q) return true;
    return (
      foldQuery(row.hermandadName).includes(q) ||
      foldQuery(row.processionDay ?? '').includes(q)
    );
  });
}

export function hermandadDayShortLabel(day: string): string {
  return day
    .replace('Viernes de Dolores', 'V. Dolores')
    .replace('Sábado de Pasión', 'S. Pasión')
    .replace('Domingo de Ramos', 'D. Ramos')
    .replace('Domingo de Resurrección', 'Resurrección')
    .replace('Miércoles Santo', 'Mié. Santo')
    .replace('Sábado Santo', 'Sáb. Santo');
}

export function buildSeasonActsSnapshot(input: {
  year: number;
  hermandadName: string;
  events: SeasonActEvent[];
  topicId?: string;
  profileId?: string | null;
  processionDay?: string | null;
  hasAccount?: boolean;
  profile?: HermandadSeasonProfile;
}): SeasonActsSnapshot {
  const hasAccount = input.hasAccount ?? true;
  const profile = input.profile ?? DEFAULT_SEASON_PROFILE;
  const own = input.events
    .filter((e) =>
      eventBelongsToHermandad(
        e,
        input.hermandadName,
        input.profileId,
        input.topicId,
      ),
    )
    .slice()
    .sort(
      (a, b) =>
        new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime(),
    );

  const milestones: SeasonActMilestone[] = SEASON_ACT_KINDS.map((def) => {
    const types =
      def.kind === 'muda' && profile.mudaMode === 'muda_only'
        ? ['muda']
        : [...def.eventTypes];
    const matched = own.filter((e) => types.includes(e.eventType));
    const slots = slotsFor(def.kind, matched, profile);
    let status = statusFor(def.kind, matched);
    if (slots.filled > 0 && slots.filled < slots.required) status = 'mixed';
    const complete = slots.filled >= slots.required && slots.required > 0;
    return {
      kind: def.kind,
      label: def.kind === 'muda' ? mudaLabel(profile.mudaMode) : def.label,
      status: complete ? status : slots.filled === 0 ? 'empty' : status,
      count: matched.length,
      filledSlots: slots.filled,
      requiredSlots: slots.required,
      statusLabel:
        slots.detail ||
        (slots.filled === 0
          ? slots.required > 1
            ? `0/${slots.required}`
            : 'Sin publicar'
          : statusLabel(def.kind, status, matched)),
      events: matched,
      pasoSlots: pasoSlotsFor(def.kind, matched, profile),
    };
  });

  const filledCount = milestones.filter(
    (m) => m.filledSlots >= m.requiredSlots && m.requiredSlots > 0,
  ).length;
  const started = milestones.some((m) => m.count > 0 || m.filledSlots > 0);
  const totalCount = milestones.length;
  const isEmpty = !started;
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
    processionDay: input.processionDay ?? null,
    hasAccount,
    milestones,
    filledCount,
    totalCount,
    isEmpty,
    isComplete,
    coverageLabel,
  };
}
