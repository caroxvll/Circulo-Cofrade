import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  DEFAULT_VISIBLE_DAYS,
  MAX_VISIBLE_DAYS,
  LiturgicalCountdownSettings,
  automaticSettings,
  computedLiturgicalDates,
  countdownVisibleDaysFromToday,
  formatLongDate,
  previewCountdown,
  resolveEasterSunday,
  resolvePalmSunday,
} from '../../core/season/season.models';
import { SeasonService } from '../../core/season/season.service';
import {
  SsDayForceState,
  SsLiturgicalDay,
  dayStatusLabel,
  formatMadridRange,
  isDayEffectivelyOpen,
} from '../../core/season/ss-days.models';

@Component({
  selector: 'app-season-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './season.component.html',
  styleUrl: './season.component.scss',
})
export class SeasonPageComponent implements OnInit {
  private readonly seasonApi = inject(SeasonService);

  readonly year = signal(new Date().getFullYear());
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly daysBusy = signal(false);
  readonly error = signal<string | null>(null);
  readonly savedOk = signal(false);
  readonly daysMsg = signal<string | null>(null);

  readonly liturgicalDays = signal<SsLiturgicalDay[]>([]);
  liveEnabled = true;

  isEnabled = true;
  visibleDays = DEFAULT_VISIBLE_DAYS;
  palmOverride = '';
  easterOverride = '';

  readonly maxDays = MAX_VISIBLE_DAYS;
  readonly formatDate = formatLongDate;
  readonly formatRange = formatMadridRange;
  readonly statusOf = dayStatusLabel;

  readonly yearOptions = computed(() => {
    const current = new Date().getFullYear();
    return [current - 1, current, current + 1];
  });

  readonly activeDay = computed(() => {
    const now = new Date();
    return this.liturgicalDays().find((d) => isDayEffectivelyOpen(d, now)) ?? null;
  });

  readonly liveOpenNow = computed(() => {
    if (!this.liveEnabled) return false;
    if (this.liturgicalDays().length === 0) return true;
    return this.activeDay() != null;
  });

  ngOnInit(): void {
    void this.reload();
  }

  autoDates() {
    return computedLiturgicalDates(this.year());
  }

  draft(): LiturgicalCountdownSettings {
    return {
      year: this.year(),
      palmSundayOverride: this.palmOverride.trim() || null,
      easterSundayOverride: this.easterOverride.trim() || null,
      visibleDaysBefore: this.visibleDays,
      isEnabled: this.isEnabled,
      usesManualDates: Boolean(this.palmOverride.trim() || this.easterOverride.trim()),
    };
  }

  resolvedPalm(): string {
    return resolvePalmSunday(this.year(), this.draft());
  }

  resolvedEaster(): string {
    return resolveEasterSunday(this.year(), this.draft());
  }

  preview() {
    return previewCountdown(new Date(), this.draft());
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    this.savedOk.set(false);
    this.daysMsg.set(null);
    try {
      const settings = await this.seasonApi.fetchForYear(this.year());
      this.applySettings(settings);
      await this.reloadDaysAndLive();
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste liturgical_countdown.sql?`
          : 'No se pudo cargar temporada',
      );
      this.applySettings(automaticSettings(this.year()));
    } finally {
      this.loading.set(false);
    }
  }

  onYearChange(value: string | number): void {
    this.year.set(Number(value));
    void this.reload();
  }

  activateFromToday(): void {
    this.visibleDays = countdownVisibleDaysFromToday(new Date(), this.draft());
    this.savedOk.set(false);
  }

  clearOverrides(): void {
    this.palmOverride = '';
    this.easterOverride = '';
    this.savedOk.set(false);
  }

  async save(): Promise<void> {
    if (
      !Number.isFinite(this.visibleDays) ||
      this.visibleDays < 0 ||
      this.visibleDays > MAX_VISIBLE_DAYS
    ) {
      this.error.set(`Los días de antelación deben estar entre 0 y ${MAX_VISIBLE_DAYS}.`);
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    this.savedOk.set(false);
    try {
      await this.seasonApi.upsert(this.draft());
      this.savedOk.set(true);
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste liturgical_countdown.sql?`
          : 'No se pudo guardar',
      );
    } finally {
      this.saving.set(false);
    }
  }

  async resetToAutoAndSave(): Promise<void> {
    this.clearOverrides();
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.seasonApi.upsert({
        ...this.draft(),
        palmSundayOverride: null,
        easterSundayOverride: null,
        usesManualDates: false,
      });
      try {
        await this.seasonApi.clearOverrides(this.year());
      } catch {
        // Si no hay fila aún, el upsert ya dejó overrides en null.
      }
      this.savedOk.set(true);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo restaurar');
    } finally {
      this.saving.set(false);
    }
  }

  async onLiveEnabledChange(enabled: boolean): Promise<void> {
    this.daysBusy.set(true);
    this.error.set(null);
    const previous = this.liveEnabled;
    this.liveEnabled = enabled;
    try {
      await this.seasonApi.setLiveEnabled(enabled);
      this.daysMsg.set(
        enabled
          ? 'En directo SS habilitado (sigue dependiendo de las jornadas).'
          : 'En directo SS desactivado globalmente.',
      );
    } catch (err) {
      this.liveEnabled = previous;
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste ss_liturgical_days.sql?`
          : 'No se pudo cambiar el en directo',
      );
    } finally {
      this.daysBusy.set(false);
    }
  }

  async regenerateDays(): Promise<void> {
    this.daysBusy.set(true);
    this.error.set(null);
    this.daysMsg.set(null);
    try {
      const days = await this.seasonApi.regenerateLiturgicalDays(
        this.year(),
        this.draft(),
      );
      this.liturgicalDays.set(days);
      this.daysMsg.set(
        `Jornadas ${this.year()} regeneradas (horarios Madrid). Se conservan Abrir/Cerrar forzados.`,
      );
    } catch (err) {
      const msg =
        err instanceof Error
          ? err.message
          : typeof err === 'object' && err && 'message' in err
            ? String((err as { message: unknown }).message)
            : 'No se pudieron generar jornadas';
      this.error.set(
        `${msg} · Ejecuta supabase/ss_liturgical_days_fix.sql en el SQL Editor y asegúrate de que tu usuario tenga role=admin.`,
      );
    } finally {
      this.daysBusy.set(false);
    }
  }

  async setForce(day: SsLiturgicalDay, state: SsDayForceState): Promise<void> {
    this.daysBusy.set(true);
    this.error.set(null);
    try {
      await this.seasonApi.setDayForceState(this.year(), day.dayKey, state);
      this.liturgicalDays.update((list) =>
        list.map((d) =>
          d.dayKey === day.dayKey ? { ...d, forceState: state } : d,
        ),
      );
      const verb =
        state === 'open' ? 'abierta' : state === 'closed' ? 'cerrada' : 'en automático';
      this.daysMsg.set(`${day.label}: jornada ${verb}.`);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo actualizar');
    } finally {
      this.daysBusy.set(false);
    }
  }

  async closeAll(): Promise<void> {
    this.daysBusy.set(true);
    this.error.set(null);
    try {
      await this.seasonApi.closeAllDays(this.year());
      this.liturgicalDays.update((list) =>
        list.map((d) => ({ ...d, forceState: 'closed' as const })),
      );
      this.daysMsg.set('Todas las jornadas cerradas manualmente.');
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cerrar');
    } finally {
      this.daysBusy.set(false);
    }
  }

  async autoAll(): Promise<void> {
    this.daysBusy.set(true);
    this.error.set(null);
    try {
      await this.seasonApi.resetAllDaysToAuto(this.year());
      this.liturgicalDays.update((list) =>
        list.map((d) => ({ ...d, forceState: 'auto' as const })),
      );
      this.daysMsg.set('Todas las jornadas en horario automático.');
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo restaurar');
    } finally {
      this.daysBusy.set(false);
    }
  }

  private async reloadDaysAndLive(): Promise<void> {
    try {
      const [live, days] = await Promise.all([
        this.seasonApi.fetchLiveSettings(),
        this.seasonApi.fetchLiturgicalDays(this.year()),
      ]);
      this.liveEnabled = live.isEnabled;
      this.liturgicalDays.set(days);
    } catch (err) {
      this.liturgicalDays.set([]);
      this.daysMsg.set(
        err instanceof Error
          ? `Jornadas no disponibles: ${err.message}. Ejecuta ss_liturgical_days.sql.`
          : 'Jornadas no disponibles. Ejecuta ss_liturgical_days.sql.',
      );
    }
  }

  private applySettings(settings: LiturgicalCountdownSettings): void {
    this.isEnabled = settings.isEnabled;
    this.visibleDays = settings.visibleDaysBefore;
    this.palmOverride = settings.palmSundayOverride ?? '';
    this.easterOverride = settings.easterSundayOverride ?? '';
  }
}
