/** Jornadas litúrgicas SS — abrir / cerrar desde admin. */

import {
  LiturgicalCountdownSettings,
  addDays,
  dateOnly,
  resolveEasterSunday,
  toIsoDate,
} from './season.models';

// Re-export helpers needed — season.models may need exporting addDays/dateOnly/toIsoDate

export type SsDayForceState = 'auto' | 'open' | 'closed';

export interface SsLiturgicalDay {
  id: string;
  year: number;
  dayKey: string;
  label: string;
  sortOrder: number;
  easterOffset: number;
  startsAt: string; // ISO
  endsAt: string;
  forceState: SsDayForceState;
  updatedAt: string | null;
}

export interface SsLiveSettings {
  isEnabled: boolean;
  updatedAt: string | null;
}

export interface SsDayTemplate {
  dayKey: string;
  label: string;
  easterOffset: number;
  sortOrder: number;
  /** Ventana especial (Madrugá). */
  special?: 'madruga' | 'resurreccion';
}

export const SS_DAY_TEMPLATES: SsDayTemplate[] = [
  { dayKey: 'domingo-ramos', label: 'Domingo de Ramos', easterOffset: -7, sortOrder: 10 },
  { dayKey: 'lunes-santo', label: 'Lunes Santo', easterOffset: -6, sortOrder: 20 },
  { dayKey: 'martes-santo', label: 'Martes Santo', easterOffset: -5, sortOrder: 30 },
  { dayKey: 'miercoles-santo', label: 'Miércoles Santo', easterOffset: -4, sortOrder: 40 },
  { dayKey: 'jueves-santo', label: 'Jueves Santo', easterOffset: -3, sortOrder: 50 },
  { dayKey: 'madruga', label: 'Madrugá', easterOffset: -2, sortOrder: 55, special: 'madruga' },
  { dayKey: 'viernes-santo', label: 'Viernes Santo', easterOffset: -2, sortOrder: 60 },
  { dayKey: 'sabado-santo', label: 'Sábado Santo', easterOffset: -1, sortOrder: 70 },
  {
    dayKey: 'domingo-resurreccion',
    label: 'Domingo de Resurrección',
    easterOffset: 0,
    sortOrder: 80,
    special: 'resurreccion',
  },
];

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

function formatMadridWall(ms: number): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Madrid',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date(ms));
  const g = (t: string) => parts.find((p) => p.type === t)?.value ?? '00';
  return `${g('year')}-${g('month')}-${g('day')}T${g('hour')}:${g('minute')}:${g('second')}`;
}

/** Fecha civil YYYY-MM-DD + hora local Madrid → ISO UTC. */
export function madridWallToIso(ymd: string, hour: number, minute = 0): string {
  const desired = `${ymd}T${pad2(hour)}:${pad2(minute)}:00`;
  let left = Date.parse(`${ymd}T00:00:00Z`) - 36e5 * 14;
  let right = Date.parse(`${ymd}T00:00:00Z`) + 36e5 * 38;
  while (right - left > 500) {
    const mid = Math.floor((left + right) / 2);
    if (formatMadridWall(mid) < desired) left = mid;
    else right = mid;
  }
  return new Date(right).toISOString();
}

function stationYmd(easterYmd: string, offset: number): string {
  return toIsoDate(addDays(dateOnly(easterYmd), offset));
}

export function buildDefaultWindow(
  easterYmd: string,
  template: SsDayTemplate,
): { startsAt: string; endsAt: string } {
  const day = stationYmd(easterYmd, template.easterOffset);
  if (template.special === 'madruga') {
    const next = toIsoDate(addDays(dateOnly(day), 1));
    return {
      startsAt: madridWallToIso(day, 20, 0),
      endsAt: madridWallToIso(next, 14, 0),
    };
  }
  if (template.special === 'resurreccion') {
    return {
      startsAt: madridWallToIso(day, 6, 0),
      endsAt: madridWallToIso(day, 23, 59),
    };
  }
  const next = toIsoDate(addDays(dateOnly(day), 1));
  return {
    startsAt: madridWallToIso(day, 6, 0),
    endsAt: madridWallToIso(next, 3, 0),
  };
}

export function generateSsDayUpserts(
  year: number,
  settings: LiturgicalCountdownSettings | null,
  preserveForce: Map<string, SsDayForceState> = new Map(),
): Omit<SsLiturgicalDay, 'id' | 'updatedAt'>[] {
  const easter = resolveEasterSunday(year, settings);
  return SS_DAY_TEMPLATES.map((t) => {
    const win = buildDefaultWindow(easter, t);
    return {
      year,
      dayKey: t.dayKey,
      label: t.label,
      sortOrder: t.sortOrder,
      easterOffset: t.easterOffset,
      startsAt: win.startsAt,
      endsAt: win.endsAt,
      forceState: preserveForce.get(t.dayKey) ?? 'auto',
    };
  });
}

export function isDayEffectivelyOpen(
  day: SsLiturgicalDay,
  now = new Date(),
): boolean {
  if (day.forceState === 'open') return true;
  if (day.forceState === 'closed') return false;
  const t = now.getTime();
  return (
    t >= new Date(day.startsAt).getTime() && t < new Date(day.endsAt).getTime()
  );
}

export function formatMadridRange(startsAt: string, endsAt: string): string {
  const opts: Intl.DateTimeFormatOptions = {
    timeZone: 'Europe/Madrid',
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  };
  const a = new Date(startsAt).toLocaleString('es-ES', opts);
  const b = new Date(endsAt).toLocaleString('es-ES', opts);
  return `${a} → ${b}`;
}

export function dayStatusLabel(
  day: SsLiturgicalDay,
  now = new Date(),
): { text: string; tone: 'open' | 'closed' | 'scheduled' | 'forced' } {
  if (day.forceState === 'open') {
    return { text: 'Forzada abierta', tone: 'forced' };
  }
  if (day.forceState === 'closed') {
    return { text: 'Cerrada', tone: 'closed' };
  }
  if (isDayEffectivelyOpen(day, now)) {
    return { text: 'Abierta ahora', tone: 'open' };
  }
  const t = now.getTime();
  if (t < new Date(day.startsAt).getTime()) {
    return { text: 'Programada', tone: 'scheduled' };
  }
  return { text: 'Finalizada', tone: 'closed' };
}
