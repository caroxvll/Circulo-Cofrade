import { Injectable, computed, inject, signal } from '@angular/core';
import { AuthService } from '../auth/auth.service';

export const COFRADEO_ACCENT = '#7a0814';
export const COFRADEO_ACCENT_DARK = '#4d0008';

export interface HermandadColorPreset {
  id: string;
  label: string;
  accent: string;
}

/** Paletas corporativas típicas de hermandades. */
export const HERMANDAD_COLOR_PRESETS: readonly HermandadColorPreset[] = [
  { id: 'cofradeo', label: 'Cofradeo', accent: COFRADEO_ACCENT },
  { id: 'granate', label: 'Granate', accent: '#6b0f1a' },
  { id: 'azul', label: 'Azul noche', accent: '#1a2f4a' },
  { id: 'verde', label: 'Verde oliva', accent: '#3d4f2f' },
  { id: 'morado', label: 'Morado', accent: '#4a1f4d' },
  { id: 'negro', label: 'Negro', accent: '#1c1714' },
] as const;

const STORAGE_PREFIX = 'cofradeo.h-theme.';

export function normalizeHex(input: string): string | null {
  const raw = input.trim().replace(/^#/, '');
  if (!/^[0-9a-fA-F]{6}$/.test(raw)) return null;
  return `#${raw.toLowerCase()}`;
}

/** Oscurece un hex (~factor 0–1). */
export function shadeHex(hex: string, factor: number): string {
  const n = normalizeHex(hex);
  if (!n) return COFRADEO_ACCENT_DARK;
  const r = Math.round(parseInt(n.slice(1, 3), 16) * factor);
  const g = Math.round(parseInt(n.slice(3, 5), 16) * factor);
  const b = Math.round(parseInt(n.slice(5, 7), 16) * factor);
  const to = (v: number) =>
    Math.max(0, Math.min(255, v)).toString(16).padStart(2, '0');
  return `#${to(r)}${to(g)}${to(b)}`;
}

@Injectable({ providedIn: 'root' })
export class HermandadThemeService {
  private readonly auth = inject(AuthService);
  private profileId: string | null = null;

  readonly accent = signal(COFRADEO_ACCENT);
  readonly accentDark = computed(() => shadeHex(this.accent(), 0.62));
  /** Último color confirmado en cuenta / navegador. */
  readonly savedAccent = signal(COFRADEO_ACCENT);
  readonly dirty = computed(
    () => this.accent().toLowerCase() !== this.savedAccent().toLowerCase(),
  );
  readonly saving = signal(false);
  readonly saveError = signal<string | null>(null);

  /**
   * Carga el color de la cuenta (DB) y, si aún no hay columna/SQL, del
   * navegador como respaldo.
   */
  loadForProfile(
    profileId: string | null | undefined,
    panelAccent?: string | null,
  ): void {
    this.profileId = profileId?.trim() || null;
    if (!this.profileId) {
      this.accent.set(COFRADEO_ACCENT);
      this.savedAccent.set(COFRADEO_ACCENT);
      return;
    }

    const fromDb = panelAccent ? normalizeHex(panelAccent) : null;
    if (fromDb) {
      this.accent.set(fromDb);
      this.savedAccent.set(fromDb);
      this.cacheLocal(fromDb);
      return;
    }

    try {
      const saved = localStorage.getItem(STORAGE_PREFIX + this.profileId);
      const hex = saved ? normalizeHex(saved) : null;
      const value = hex ?? COFRADEO_ACCENT;
      this.accent.set(value);
      this.savedAccent.set(value);
    } catch {
      this.accent.set(COFRADEO_ACCENT);
      this.savedAccent.set(COFRADEO_ACCENT);
    }
  }

  /** Aplica el color al panel al momento (sin persistir). */
  applyAccent(hex: string): boolean {
    const normalized = normalizeHex(hex);
    if (!normalized) return false;
    this.accent.set(normalized);
    this.saveError.set(null);
    return true;
  }

  /** Restaura el acento Cofradeo en pantalla (sigue haciendo falta Guardar). */
  applyDefault(): void {
    this.accent.set(COFRADEO_ACCENT);
    this.saveError.set(null);
  }

  /** Guarda en cuenta (+ caché local) el color actualmente aplicado. */
  async saveCurrent(): Promise<boolean> {
    if (!this.profileId) return false;
    const hex = this.accent();
    const toStore = hex === COFRADEO_ACCENT ? null : hex;
    this.saving.set(true);
    this.saveError.set(null);
    this.cacheLocal(toStore);
    try {
      await this.auth.setPanelAccent(toStore);
      this.savedAccent.set(hex);
      return true;
    } catch (err) {
      const msg =
        err instanceof Error ? err.message : 'No se pudo guardar en tu cuenta';
      if (/panel_accent|schema cache|column/i.test(msg)) {
        // Sin SQL: al menos queda en este navegador.
        this.savedAccent.set(hex);
        this.saveError.set(
          'Guardado en este navegador. Para la cuenta, ejecuta hermandad_panel_accent.sql en Supabase.',
        );
        return true;
      }
      this.saveError.set(msg);
      return false;
    } finally {
      this.saving.set(false);
    }
  }

  private cacheLocal(hex: string | null): void {
    if (!this.profileId) return;
    try {
      const key = STORAGE_PREFIX + this.profileId;
      if (!hex) localStorage.removeItem(key);
      else localStorage.setItem(key, hex);
    } catch {
      /* ignore */
    }
  }
}
