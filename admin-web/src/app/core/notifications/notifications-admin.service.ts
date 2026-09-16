import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';

export interface NotificationsOverview {
  days: number;
  since: string;
  totalUsers: number;
  pushEnabledUsers: number;
  pushDisabledUsers: number;
  pushOnWithDevice: number;
  pushOnNoDevice: number;
  usersWithToken: number;
  tokenCount: number;
  tokensByPlatform: Record<string, number>;
  notificationsTotal: number;
  byType: { type: string; count: number }[];
  byDay: { day: string; count: number }[];
}

export interface UserNotifDiag {
  found: boolean;
  handle?: string;
  userId?: string;
  displayName?: string | null;
  role?: string;
  pushEnabled?: boolean;
  prefs?: Record<string, unknown> | null;
  tokens?: { platform: string; tokenPreview: string; updatedAt: string }[];
  tokenCount?: number;
  recentNotifications?: {
    id: string;
    type: string;
    title: string;
    createdAt: string;
    read: boolean;
  }[];
}

export type PushUserFilter =
  | 'all'
  | 'on'
  | 'off'
  | 'on_no_token'
  | 'off_with_token';

export interface PushUserRow {
  userId: string;
  handle: string;
  displayName: string | null;
  role: string;
  pushEnabled: boolean;
  tokenCount: number;
  platforms: string;
  prefs: Record<string, unknown> | null;
}

export interface PushUsersPage {
  total: number;
  limit: number;
  offset: number;
  filter: PushUserFilter;
  rows: PushUserRow[];
}

/** Prefs que mostramos como chips en la tabla (orden visual). */
export const TABLE_PREF_KEYS = [
  'notify_mentions',
  'notify_topics',
  'notify_hashtags',
  'notify_profiles',
  'notify_followers',
  'notify_reactions',
  'notify_calendar',
  'notify_quiz',
  'notify_news',
] as const;

@Injectable({ providedIn: 'root' })
export class NotificationsAdminService {
  async fetchOverview(days = 30): Promise<NotificationsOverview> {
    const { data, error } = await getSupabase().rpc(
      'get_notifications_admin_overview',
      { p_days: days },
    );
    if (error) throw error;
    const raw = (data ?? {}) as Record<string, unknown>;
    return {
      days: Number(raw['days'] ?? days),
      since: String(raw['since'] ?? ''),
      totalUsers: Number(raw['totalUsers'] ?? 0),
      pushEnabledUsers: Number(raw['pushEnabledUsers'] ?? 0),
      pushDisabledUsers: Number(raw['pushDisabledUsers'] ?? 0),
      pushOnWithDevice: Number(raw['pushOnWithDevice'] ?? 0),
      pushOnNoDevice: Number(raw['pushOnNoDevice'] ?? 0),
      usersWithToken: Number(raw['usersWithToken'] ?? 0),
      tokenCount: Number(raw['tokenCount'] ?? 0),
      tokensByPlatform: (raw['tokensByPlatform'] as Record<string, number>) ?? {},
      notificationsTotal: Number(raw['notificationsTotal'] ?? 0),
      byType: ((raw['byType'] as { type: string; count: number }[]) ?? []).map(
        (row) => ({
          type: String(row.type ?? ''),
          count: Number(row.count ?? 0),
        }),
      ),
      byDay: ((raw['byDay'] as { day: string; count: number }[]) ?? []).map(
        (row) => ({
          day: String(row.day ?? ''),
          count: Number(row.count ?? 0),
        }),
      ),
    };
  }

  async fetchUserDiag(handle: string): Promise<UserNotifDiag> {
    const { data, error } = await getSupabase().rpc(
      'get_notifications_user_diag',
      { p_handle: handle },
    );
    if (error) throw error;
    return (data ?? { found: false }) as UserNotifDiag;
  }

  async listPushUsers(input: {
    filter?: PushUserFilter;
    search?: string;
    limit?: number;
    offset?: number;
  }): Promise<PushUsersPage> {
    const { data, error } = await getSupabase().rpc('list_push_users', {
      p_filter: input.filter ?? 'all',
      p_search: input.search?.trim() || null,
      p_limit: input.limit ?? 50,
      p_offset: input.offset ?? 0,
    });
    if (error) throw error;
    const raw = (data ?? {}) as Record<string, unknown>;
    const rows = ((raw['rows'] as Record<string, unknown>[]) ?? []).map(
      (row) => ({
        userId: String(row['userId'] ?? ''),
        handle: String(row['handle'] ?? ''),
        displayName: (row['displayName'] as string | null) ?? null,
        role: String(row['role'] ?? ''),
        pushEnabled: Boolean(row['pushEnabled']),
        tokenCount: Number(row['tokenCount'] ?? 0),
        platforms: String(row['platforms'] ?? ''),
        prefs: (row['prefs'] as Record<string, unknown> | null) ?? null,
      }),
    );
    return {
      total: Number(raw['total'] ?? 0),
      limit: Number(raw['limit'] ?? 50),
      offset: Number(raw['offset'] ?? 0),
      filter: (raw['filter'] as PushUserFilter) ?? 'all',
      rows,
    };
  }

  typeLabel(type: string): string {
    switch (type) {
      case 'topic_pending_review':
        return 'Tema pendiente';
      case 'new_report':
        return 'Nuevo reporte';
      case 'topic_approved':
        return 'Tema aprobado';
      case 'topic_rejected':
        return 'Tema rechazado';
      case 'forum_reply':
        return 'Respuesta en foro';
      case 'mention':
        return 'Mención';
      case 'follow':
      case 'new_follower':
        return 'Seguidor';
      case 'reaction':
        return 'Reacción';
      case 'calendar':
      case 'calendar_event':
        return 'Calendario';
      case 'quiz':
      case 'quiz_live':
        return 'Quiz';
      case 'news':
        return 'Noticias';
      case 'hashtag':
        return 'Hashtag';
      default:
        return type || '—';
    }
  }

  prefLabel(key: string): string {
    switch (key) {
      case 'push_enabled':
        return 'Avisos push';
      case 'notify_hashtags':
        return 'Hashtags';
      case 'notify_profiles':
        return 'Perfiles';
      case 'notify_topics':
        return 'Hilos';
      case 'notify_mentions':
        return 'Menciones';
      case 'notify_followers':
        return 'Seguidores';
      case 'notify_calendar':
        return 'Calendario';
      case 'notify_reactions':
        return 'Reacciones';
      case 'notify_quiz':
        return 'Quiz';
      case 'notify_news':
        return 'Noticias';
      default:
        return key.replace(/^notify_/, '').replaceAll('_', ' ');
    }
  }

  prefShort(key: string): string {
    switch (key) {
      case 'notify_hashtags':
        return 'Tags';
      case 'notify_profiles':
        return 'Perfil';
      case 'notify_topics':
        return 'Hilos';
      case 'notify_mentions':
        return '@';
      case 'notify_followers':
        return 'Seg.';
      case 'notify_calendar':
        return 'Cal.';
      case 'notify_reactions':
        return 'Reacc.';
      case 'notify_quiz':
        return 'Quiz';
      case 'notify_news':
        return 'News';
      default:
        return this.prefLabel(key).slice(0, 6);
    }
  }

  platformLabel(platform: string): string {
    switch (platform.toLowerCase()) {
      case 'ios':
        return 'iPhone';
      case 'android':
        return 'Android';
      case 'web':
        return 'Web';
      default:
        return platform;
    }
  }
}
