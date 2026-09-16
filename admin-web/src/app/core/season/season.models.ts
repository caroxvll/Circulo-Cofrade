/** Cuenta atrás litúrgica (misma lógica que la app Flutter). */

export const DEFAULT_VISIBLE_DAYS = 60;
export const MAX_VISIBLE_DAYS = 400;

export interface LiturgicalCountdownSettings {
  year: number;
  palmSundayOverride: string | null; // YYYY-MM-DD
  easterSundayOverride: string | null;
  visibleDaysBefore: number;
  isEnabled: boolean;
  usesManualDates: boolean;
}

export interface LiturgicalDates {
  palmSunday: string;
  easterSunday: string;
}

export interface CountdownPreview {
  headline: string;
  subtitle: string | null;
  visible: boolean;
}

export function dateOnly(isoOrDate: string | Date): Date {
  if (typeof isoOrDate === 'string') {
    return new Date(`${isoOrDate.slice(0, 10)}T12:00:00`);
  }
  return new Date(isoOrDate.getFullYear(), isoOrDate.getMonth(), isoOrDate.getDate(), 12);
}

export function toIsoDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function addDays(date: Date, days: number): Date {
  const d = dateOnly(date);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + days, 12);
}

function daysBetween(from: Date, to: Date): number {
  const a = dateOnly(from);
  const b = dateOnly(to);
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

/** Domingo de Pascua — algoritmo gregoriano (Meeus). */
export function easterSunday(year: number): Date {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(year, month - 1, day, 12);
}

export function computedLiturgicalDates(year: number): LiturgicalDates {
  const easter = easterSunday(year);
  const palm = addDays(easter, -7);
  return {
    palmSunday: toIsoDate(palm),
    easterSunday: toIsoDate(easter),
  };
}

export function resolvePalmSunday(
  year: number,
  settings: LiturgicalCountdownSettings | null,
): string {
  if (settings?.palmSundayOverride) return settings.palmSundayOverride.slice(0, 10);
  return computedLiturgicalDates(year).palmSunday;
}

export function resolveEasterSunday(
  year: number,
  settings: LiturgicalCountdownSettings | null,
): string {
  if (settings?.easterSundayOverride) {
    return settings.easterSundayOverride.slice(0, 10);
  }
  if (settings?.palmSundayOverride) {
    return toIsoDate(addDays(dateOnly(settings.palmSundayOverride), 7));
  }
  return computedLiturgicalDates(year).easterSunday;
}

export function formatLongDate(iso: string): string {
  const date = dateOnly(iso);
  const label = date.toLocaleDateString('es-ES', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
  return label.charAt(0).toUpperCase() + label.slice(1);
}

/** Días de antelación para que el banner sea visible hoy. */
export function countdownVisibleDaysFromToday(
  reference: Date,
  settings: LiturgicalCountdownSettings | null,
): number {
  const today = dateOnly(reference);
  let year = today.getFullYear();
  let palm = resolvePalmSunday(year, settings);
  const easter = resolveEasterSunday(year, settings);

  if (today.getTime() > dateOnly(easter).getTime()) {
    year += 1;
    palm = resolvePalmSunday(year, settings?.year === year ? settings : null);
  }

  const days = daysBetween(today, dateOnly(palm));
  return days < 0 ? 0 : days;
}

export function previewCountdown(
  reference: Date,
  settings: LiturgicalCountdownSettings,
): CountdownPreview {
  if (!settings.isEnabled) {
    return {
      headline: 'Cuenta atrás desactivada',
      subtitle: 'El banner no se muestra en la app.',
      visible: false,
    };
  }

  const today = dateOnly(reference);
  let year = today.getFullYear();
  let palm = dateOnly(resolvePalmSunday(year, settings));
  let easter = dateOnly(resolveEasterSunday(year, settings));

  if (today.getTime() > easter.getTime()) {
    year += 1;
    palm = dateOnly(resolvePalmSunday(year, null));
    easter = dateOnly(resolveEasterSunday(year, null));
  }

  const visibleDays = settings.visibleDaysBefore;
  const windowStart = addDays(palm, -visibleDays);
  const holySaturday = addDays(easter, -1);

  if (today.getTime() < windowStart.getTime() || today.getTime() > holySaturday.getTime()) {
    const daysToWindow = daysBetween(today, windowStart);
    return {
      headline: 'Fuera de ventana',
      subtitle:
        daysToWindow > 0
          ? `El banner empezará a verse en ${daysToWindow} día(s) (antelación ${visibleDays}).`
          : 'Ya pasó el Sábado Santo de este ciclo.',
      visible: false,
    };
  }

  const daysToPalm = daysBetween(today, palm);
  if (daysToPalm > 1) {
    return {
      headline: `Quedan ${daysToPalm} días`,
      subtitle: 'para el Domingo de Ramos',
      visible: true,
    };
  }
  if (daysToPalm === 1) {
    return {
      headline: 'Mañana es Domingo de Ramos',
      subtitle: null,
      visible: true,
    };
  }
  if (daysToPalm === 0) {
    return {
      headline: '¡Hoy es Domingo de Ramos!',
      subtitle: 'Comienza la Semana Santa',
      visible: true,
    };
  }

  const daysToEaster = daysBetween(today, easter);
  return {
    headline: 'Semana Santa en curso',
    subtitle:
      daysToEaster === 1
        ? 'Mañana es Domingo de Resurrección'
        : `Faltan ${daysToEaster} días para el Domingo de Resurrección`,
    visible: true,
  };
}

export function automaticSettings(year: number): LiturgicalCountdownSettings {
  return {
    year,
    palmSundayOverride: null,
    easterSundayOverride: null,
    visibleDaysBefore: DEFAULT_VISIBLE_DAYS,
    isEnabled: true,
    usesManualDates: false,
  };
}
