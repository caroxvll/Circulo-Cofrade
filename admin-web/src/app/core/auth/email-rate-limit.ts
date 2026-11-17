/**
 * Límites de cliente para no quemar el cupo de emails de Supabase Auth.
 *
 * Con el SMTP integrado de Supabase: ~2 emails/hora por proyecto.
 * Además, /recover suele pedir 60s entre intentos del mismo usuario.
 *
 * Estos límites NO sustituyen los del servidor; evitan clics repetidos
 * y dan mensajes claros. En producción conviene SMTP propio.
 */

const STORAGE_KEY = 'cc_auth_email_rate_v1';

/** Espera mínima entre recuperaciones del mismo email (ms). */
export const RECOVER_EMAIL_COOLDOWN_MS = 60_000;

/** Máximo de recuperaciones por dispositivo en la ventana. */
export const RECOVER_DEVICE_MAX = 2;

/** Ventana del cupo por dispositivo (ms). */
export const RECOVER_DEVICE_WINDOW_MS = 60 * 60 * 1000;

interface RateState {
  /** email -> timestamps de intentos */
  byEmail: Record<string, number[]>;
  /** timestamps de intentos en este dispositivo */
  device: number[];
}

function now(): number {
  return Date.now();
}

function load(): RateState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { byEmail: {}, device: [] };
    const parsed = JSON.parse(raw) as Partial<RateState>;
    return {
      byEmail: parsed.byEmail && typeof parsed.byEmail === 'object' ? parsed.byEmail : {},
      device: Array.isArray(parsed.device) ? parsed.device.filter((n) => typeof n === 'number') : [],
    };
  } catch {
    return { byEmail: {}, device: [] };
  }
}

function save(state: RateState): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    /* private mode */
  }
}

function prune(timestamps: number[], windowMs: number, at = now()): number[] {
  return timestamps.filter((t) => at - t < windowMs);
}

export interface RecoverRateBlock {
  blocked: true;
  message: string;
  retryAfterMs: number;
}

export interface RecoverRateOk {
  blocked: false;
}

export type RecoverRateCheck = RecoverRateBlock | RecoverRateOk;

/** Comprueba si se puede pedir recuperación de contraseña. */
export function checkPasswordRecoverRate(email: string): RecoverRateCheck {
  const key = email.trim().toLowerCase();
  const at = now();
  const state = load();

  const device = prune(state.device, RECOVER_DEVICE_WINDOW_MS, at);
  if (device.length >= RECOVER_DEVICE_MAX) {
    const oldest = Math.min(...device);
    const retryAfterMs = Math.max(0, RECOVER_DEVICE_WINDOW_MS - (at - oldest));
    return {
      blocked: true,
      retryAfterMs,
      message: `Has alcanzado el límite de recuperaciones desde este dispositivo (${RECOVER_DEVICE_MAX} por hora). Espera ${formatWait(retryAfterMs)}.`,
    };
  }

  const emailHits = prune(state.byEmail[key] ?? [], RECOVER_EMAIL_COOLDOWN_MS * 10, at);
  const last = emailHits.length ? Math.max(...emailHits) : 0;
  if (last && at - last < RECOVER_EMAIL_COOLDOWN_MS) {
    const retryAfterMs = RECOVER_EMAIL_COOLDOWN_MS - (at - last);
    return {
      blocked: true,
      retryAfterMs,
      message: `Espera ${formatWait(retryAfterMs)} antes de pedir otro enlace para este email.`,
    };
  }

  return { blocked: false };
}

/** Registra un intento (llamar tras éxito o tras envío aceptado por Auth). */
export function recordPasswordRecoverAttempt(email: string): void {
  const key = email.trim().toLowerCase();
  const at = now();
  const state = load();
  state.device = prune(state.device, RECOVER_DEVICE_WINDOW_MS, at);
  state.device.push(at);
  const emailHits = prune(state.byEmail[key] ?? [], RECOVER_DEVICE_WINDOW_MS, at);
  emailHits.push(at);
  state.byEmail[key] = emailHits;
  save(state);
}

export function formatWait(ms: number): string {
  const sec = Math.ceil(ms / 1000);
  if (sec < 60) return `${sec} s`;
  const min = Math.ceil(sec / 60);
  return min === 1 ? '1 minuto' : `${min} minutos`;
}

/** Interpreta errores de Supabase Auth relacionados con emails / rate limit. */
export function mapAuthEmailError(err: unknown): string | null {
  const raw =
    err && typeof err === 'object' && 'message' in err
      ? String((err as { message: unknown }).message)
      : err instanceof Error
        ? err.message
        : String(err ?? '');
  const lower = raw.toLowerCase();
  const status =
    err && typeof err === 'object' && 'status' in err
      ? Number((err as { status: unknown }).status)
      : 0;
  const code =
    err && typeof err === 'object' && 'code' in err
      ? String((err as { code: unknown }).code)
      : '';

  if (
    status === 429 ||
    code.includes('over_email') ||
    lower.includes('rate limit') ||
    lower.includes('email rate limit') ||
    lower.includes('over_email_send_rate_limit')
  ) {
    return 'Se ha alcanzado el límite de emails del servidor. Espera unos minutos (con el email de prueba de Supabase suele ser ~2 por hora) o configura un SMTP propio en producción.';
  }

  if (lower.includes('error sending') || lower.includes('smtp')) {
    return 'No se pudo enviar el email ahora mismo. Inténtalo más tarde.';
  }

  return null;
}
