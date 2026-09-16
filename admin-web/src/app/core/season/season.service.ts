import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';
import {
  LiturgicalCountdownSettings,
  automaticSettings,
} from './season.models';
import {
  SsDayForceState,
  SsLiturgicalDay,
  SsLiveSettings,
  generateSsDayUpserts,
} from './ss-days.models';

@Injectable({ providedIn: 'root' })
export class SeasonService {
  async fetchForYear(year: number): Promise<LiturgicalCountdownSettings> {
    const { data, error } = await getSupabase()
      .from('liturgical_countdown_settings')
      .select('*')
      .eq('year', year)
      .maybeSingle();
    if (error) throw error;
    if (!data) return automaticSettings(year);
    return this.mapRow(data as Record<string, unknown>, year);
  }

  async upsert(settings: LiturgicalCountdownSettings): Promise<void> {
    const { error } = await getSupabase()
      .from('liturgical_countdown_settings')
      .upsert({
        year: settings.year,
        palm_sunday_date: settings.palmSundayOverride || null,
        easter_sunday_date: settings.easterSundayOverride || null,
        visible_days_before: settings.visibleDaysBefore,
        is_enabled: settings.isEnabled,
        updated_at: new Date().toISOString(),
      });
    if (error) throw error;
  }

  async clearOverrides(year: number): Promise<void> {
    const { error } = await getSupabase()
      .from('liturgical_countdown_settings')
      .update({
        palm_sunday_date: null,
        easter_sunday_date: null,
        updated_at: new Date().toISOString(),
      })
      .eq('year', year);
    if (error) throw error;
  }

  async fetchLiveSettings(): Promise<SsLiveSettings> {
    const { data, error } = await getSupabase()
      .from('ss_live_settings')
      .select('*')
      .eq('id', 1)
      .maybeSingle();
    if (error) throw error;
    return {
      isEnabled: Boolean(data?.['is_enabled'] ?? true),
      updatedAt: (data?.['updated_at'] as string | null) ?? null,
    };
  }

  async setLiveEnabled(enabled: boolean): Promise<void> {
    const { error } = await getSupabase()
      .from('ss_live_settings')
      .upsert({
        id: 1,
        is_enabled: enabled,
        updated_at: new Date().toISOString(),
      });
    if (error) throw error;
  }

  async fetchLiturgicalDays(year: number): Promise<SsLiturgicalDay[]> {
    const { data, error } = await getSupabase()
      .from('ss_liturgical_days')
      .select('*')
      .eq('year', year)
      .order('sort_order', { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapDay(row as Record<string, unknown>));
  }

  async regenerateLiturgicalDays(
    year: number,
    settings: LiturgicalCountdownSettings,
  ): Promise<SsLiturgicalDay[]> {
    const existing = await this.fetchLiturgicalDays(year);
    const preserve = new Map<string, SsDayForceState>();
    for (const d of existing) preserve.set(d.dayKey, d.forceState);

    const rows = generateSsDayUpserts(year, settings, preserve).map((d) => ({
      year: d.year,
      day_key: d.dayKey,
      label: d.label,
      sort_order: d.sortOrder,
      easter_offset: d.easterOffset,
      starts_at: d.startsAt,
      ends_at: d.endsAt,
      force_state: d.forceState,
      updated_at: new Date().toISOString(),
    }));

    // Preferido: RPC security definer (evita fallos de upsert/RLS).
    const rpc = await getSupabase().rpc('admin_upsert_ss_liturgical_days', {
      p_rows: rows,
    });
    if (!rpc.error) {
      return this.fetchLiturgicalDays(year);
    }

    // Fallback: upsert directo
    const upsert = await getSupabase()
      .from('ss_liturgical_days')
      .upsert(rows, { onConflict: 'year,day_key' });
    if (!upsert.error) {
      return this.fetchLiturgicalDays(year);
    }

    // Último recurso: borrar año + insert
    const del = await getSupabase()
      .from('ss_liturgical_days')
      .delete()
      .eq('year', year);
    if (del.error) {
      throw this.toError(rpc.error ?? upsert.error ?? del.error);
    }
    const ins = await getSupabase().from('ss_liturgical_days').insert(rows);
    if (ins.error) {
      throw this.toError(ins.error);
    }
    return this.fetchLiturgicalDays(year);
  }

  private toError(err: { message?: string; code?: string; details?: string; hint?: string }): Error {
    const parts = [
      err.message,
      err.code ? `código ${err.code}` : null,
      err.details,
      err.hint,
    ].filter(Boolean);
    return new Error(parts.join(' · ') || 'Error desconocido al guardar jornadas');
  }

  async setDayForceState(
    year: number,
    dayKey: string,
    forceState: SsDayForceState,
  ): Promise<void> {
    const { error } = await getSupabase()
      .from('ss_liturgical_days')
      .update({
        force_state: forceState,
        updated_at: new Date().toISOString(),
      })
      .eq('year', year)
      .eq('day_key', dayKey);
    if (error) throw error;
  }

  async closeAllDays(year: number): Promise<void> {
    const { error } = await getSupabase()
      .from('ss_liturgical_days')
      .update({
        force_state: 'closed',
        updated_at: new Date().toISOString(),
      })
      .eq('year', year);
    if (error) throw error;
  }

  async resetAllDaysToAuto(year: number): Promise<void> {
    const { error } = await getSupabase()
      .from('ss_liturgical_days')
      .update({
        force_state: 'auto',
        updated_at: new Date().toISOString(),
      })
      .eq('year', year);
    if (error) throw error;
  }

  private mapDay(row: Record<string, unknown>): SsLiturgicalDay {
    return {
      id: String(row['id']),
      year: Number(row['year']),
      dayKey: String(row['day_key']),
      label: String(row['label']),
      sortOrder: Number(row['sort_order']),
      easterOffset: Number(row['easter_offset']),
      startsAt: String(row['starts_at']),
      endsAt: String(row['ends_at']),
      forceState: (row['force_state'] as SsDayForceState) ?? 'auto',
      updatedAt: (row['updated_at'] as string | null) ?? null,
    };
  }

  private mapRow(
    row: Record<string, unknown>,
    fallbackYear: number,
  ): LiturgicalCountdownSettings {
    const palm = (row['palm_sunday_date'] as string | null) ?? null;
    const easter = (row['easter_sunday_date'] as string | null) ?? null;
    return {
      year: Number(row['year'] ?? fallbackYear),
      palmSundayOverride: palm,
      easterSundayOverride: easter,
      visibleDaysBefore: Number(row['visible_days_before'] ?? 60),
      isEnabled: Boolean(row['is_enabled'] ?? true),
      usesManualDates: Boolean(palm || easter),
    };
  }
}
