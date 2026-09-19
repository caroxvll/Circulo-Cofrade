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

export interface DispatchJobRow {
  id: string;
  kind: string;
  sourceId: string;
  title: string;
  status: string;
  processedCount: number;
  retryCount: number;
  errorMessage: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface DispatchOverview {
  byStatus: Record<string, number>;
  byKindPending: { kind: string; jobs: number; processed: number }[];
  pendingCount: number;
  failedCount: number;
  doneLast24h: number;
  processedLast24h: number;
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

  async fetchDispatchOverview(): Promise<DispatchOverview> {
    const { data, error } = await getSupabase().rpc(
      'staff_notification_dispatch_overview',
    );
    if (error) throw error;
    const raw = (data ?? {}) as Record<string, unknown>;
    const byKind = ((raw['byKindPending'] as Record<string, unknown>[]) ?? []).map(
      (row) => ({
        kind: String(row['kind'] ?? ''),
        jobs: Number(row['jobs'] ?? 0),
        processed: Number(row['processed'] ?? 0),
      }),
    );
    return {
      byStatus: (raw['byStatus'] as Record<string, number>) ?? {},
      byKindPending: byKind,
      pendingCount: Number(raw['pendingCount'] ?? 0),
      failedCount: Number(raw['failedCount'] ?? 0),
      doneLast24h: Number(raw['doneLast24h'] ?? 0),
      processedLast24h: Number(raw['processedLast24h'] ?? 0),
    };
  }

  async listDispatchJobs(limit = 40): Promise<DispatchJobRow[]> {
    const { data, error } = await getSupabase()
      .from('notification_dispatch_jobs')
      .select(
        'id, kind, source_id, title, status, processed_count, retry_count, error_message, created_at, updated_at',
      )
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: String(row['id'] ?? ''),
      kind: String(row['kind'] ?? ''),
      sourceId: String(row['source_id'] ?? ''),
      title: String(row['title'] ?? ''),
      status: String(row['status'] ?? ''),
      processedCount: Number(row['processed_count'] ?? 0),
      retryCount: Number(row['retry_count'] ?? 0),
      errorMessage: (row['error_message'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
      updatedAt: String(row['updated_at'] ?? ''),
    }));
  }

  async processDispatchNow(): Promise<{ processedTotal: number }> {
    const { data, error } = await getSupabase().rpc(
      'staff_process_notification_dispatch',
      { p_limit: 500, p_max_jobs: 8 },
    );
    if (error) throw error;
    const raw = (data ?? {}) as Record<string, unknown>;
    return { processedTotal: Number(raw['processedTotal'] ?? 0) };
  }

  async retryFailedDispatchJobs(): Promise<number> {
    const { data, error } = await getSupabase().rpc(
      'staff_retry_failed_notification_jobs',
    );
    if (error) throw error;
    return Number(data ?? 0);
  }

  async reloadApiSchema(): Promise<void> {
    const { error } = await getSupabase().rpc('staff_reload_postgrest_schema');
    if (error) throw error;
  }

  kindLabel(kind: string): string {
    switch (kind) {
      case 'news_published':
        return 'Noticias';
      case 'topic_followers':
        return 'Hilo seguido';
      case 'hashtag_followers':
        return 'Hashtag';
      case 'profile_followers':
        return 'Perfil seguido';
      case 'calendar_broadcast':
        return 'Calendario';
      case 'quiz_broadcast':
        return 'Quiz';
      default:
        return kind || '—';
    }
  }

  statusLabel(status: string): string {
    switch (status) {
      case 'pending':
        return 'En cola';
      case 'processing':
        return 'Enviando';
      case 'done':
        return 'Hecho';
      case 'failed':
        return 'Fallido';
      default:
        return status;
    }
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
