import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';

export interface DemoWorldStatus {
  enabled: boolean;
  demoUsers: number;
  demoTopics: number;
  demoReplies: number;
  demoEvents: number;
  seeded: boolean;
}

export interface DemoSeedResult {
  ok: boolean;
  message?: string;
  loginHint?: string;
  status?: DemoWorldStatus;
}

export interface DemoWipeResult {
  ok: boolean;
  usersDeleted: number;
  topicsDeleted: number;
  repliesDeleted: number;
  eventsDeleted: number;
  likesDeleted: number;
  followsDeleted: number;
}

@Injectable({ providedIn: 'root' })
export class DemoWorldService {
  async seed(): Promise<DemoSeedResult> {
    const { data, error } = await getSupabase().rpc('seed_demo_world');
    if (error) throw this.toError(error);
    const raw = (data ?? {}) as Record<string, unknown>;
    return {
      ok: Boolean(raw['ok']),
      message: String(raw['message'] ?? ''),
      loginHint: String(raw['loginHint'] ?? ''),
      status: raw['status']
        ? {
            enabled: Boolean((raw['status'] as Record<string, unknown>)['enabled']),
            demoUsers: Number((raw['status'] as Record<string, unknown>)['demoUsers'] ?? 0),
            demoTopics: Number((raw['status'] as Record<string, unknown>)['demoTopics'] ?? 0),
            demoReplies: Number((raw['status'] as Record<string, unknown>)['demoReplies'] ?? 0),
            demoEvents: Number((raw['status'] as Record<string, unknown>)['demoEvents'] ?? 0),
            seeded: Boolean((raw['status'] as Record<string, unknown>)['seeded']),
          }
        : undefined,
    };
  }

  async wipe(): Promise<DemoWipeResult> {
    const { data, error } = await getSupabase().rpc('wipe_demo_world');
    if (error) throw this.toError(error);
    const raw = (data ?? {}) as Record<string, unknown>;
    return {
      ok: Boolean(raw['ok']),
      usersDeleted: Number(raw['usersDeleted'] ?? 0),
      topicsDeleted: Number(raw['topicsDeleted'] ?? 0),
      repliesDeleted: Number(raw['repliesDeleted'] ?? 0),
      eventsDeleted: Number(raw['eventsDeleted'] ?? 0),
      likesDeleted: Number(raw['likesDeleted'] ?? 0),
      followsDeleted: Number(raw['followsDeleted'] ?? 0),
    };
  }

  async fetchStatus(): Promise<DemoWorldStatus> {
    const { data, error } = await getSupabase().rpc('get_demo_world_status');
    if (error) throw this.toError(error);
    const raw = (data ?? {}) as Record<string, unknown>;
    return {
      enabled: Boolean(raw['enabled']),
      demoUsers: Number(raw['demoUsers'] ?? 0),
      demoTopics: Number(raw['demoTopics'] ?? 0),
      demoReplies: Number(raw['demoReplies'] ?? 0),
      demoEvents: Number(raw['demoEvents'] ?? 0),
      seeded: Boolean(raw['seeded']),
    };
  }

  private toError(err: unknown): Error {
    if (err instanceof Error) return err;
    const e = err as {
      message?: string;
      details?: string;
      hint?: string;
      code?: string;
    };
    const parts = [e.message, e.details, e.hint, e.code ? `(${e.code})` : '']
      .map((p) => (p ?? '').trim())
      .filter(Boolean);
    return new Error(parts.join(' — ') || 'Error desconocido en simulación');
  }
}
