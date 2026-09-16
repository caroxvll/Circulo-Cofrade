import { Injectable, inject, signal } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { EventsService } from '../events/events.service';
import { getSupabase } from '../supabase.client';
import {
  ModerationReportGroup,
  ModerationReportItem,
  ModerationTopic,
  PendingEvent,
  QueueCounts,
} from './moderation.models';

@Injectable({ providedIn: 'root' })
export class ModerationService {
  private readonly auth = inject(AuthService);
  private readonly eventsApi = inject(EventsService);

  readonly counts = signal<QueueCounts>({
    topics: 0,
    reports: 0,
    events: 0,
    closeRequests: 0,
  });
  readonly countsLoading = signal(false);

  private filterByForumAccess<T extends { forumId?: string | null; targetForumId?: string | null }>(
    rows: T[],
    forumKey: 'forumId' | 'targetForumId' = 'forumId',
  ): T[] {
    if (this.auth.isAdmin()) return rows;
    const allowed = this.auth.moderatedForumIds();
    if (allowed.size === 0) return [];
    return rows.filter((row) => {
      const forumId = row[forumKey];
      return typeof forumId === 'string' && allowed.has(forumId);
    });
  }

  async refreshCounts(): Promise<void> {
    this.countsLoading.set(true);
    try {
      const [topics, reports, eventsCount, closes] = await Promise.all([
        this.fetchPendingTopics(),
        this.fetchPendingReportGroups(),
        this.auth.isAdmin() ? this.eventsApi.countPending() : Promise.resolve(0),
        this.fetchCloseRequestedTopics(),
      ]);
      this.counts.set({
        topics: topics.length,
        reports: reports.length,
        events: eventsCount,
        closeRequests: closes.length,
      });
    } finally {
      this.countsLoading.set(false);
    }
  }

  async fetchPendingTopics(): Promise<ModerationTopic[]> {
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select('id, forum_id, title, excerpt, author_handle, cover_image_url, created_at')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) throw error;
    const mapped = (data ?? []).map((row) => this.mapTopic(row));
    return this.filterByForumAccess(mapped);
  }

  async fetchRejectedTopics(offset = 0, limit = 20): Promise<ModerationTopic[]> {
    let query = getSupabase()
      .from('forum_topics')
      .select(
        'id, forum_id, title, excerpt, author_handle, cover_image_url, created_at, rejection_reason, rejected_at',
      )
      .eq('status', 'rejected');

    if (!this.auth.isAdmin()) {
      const ids = [...this.auth.moderatedForumIds()];
      if (ids.length === 0) return [];
      query = query.in('forum_id', ids);
    }

    const { data, error } = await query
      .order('rejected_at', { ascending: false, nullsFirst: false })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapTopic(row));
  }

  async approveTopic(topicId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('forum_topics')
      .update({
        status: 'published',
        rejection_reason: null,
        rejected_at: null,
      })
      .eq('id', topicId);
    if (error) throw error;
  }

  async rejectTopic(topicId: string, reason: string): Promise<void> {
    const trimmed = reason.trim();
    if (trimmed.length < 3) {
      throw new Error('El motivo de rechazo debe tener al menos 3 caracteres.');
    }
    const { error } = await getSupabase()
      .from('forum_topics')
      .update({
        status: 'rejected',
        rejection_reason: trimmed,
        rejected_at: new Date().toISOString(),
      })
      .eq('id', topicId);
    if (error) throw error;
  }

  async deleteTopic(topicId: string): Promise<void> {
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .delete()
      .eq('id', topicId)
      .select('id');
    if (error) throw error;
    if (!data?.length) throw new Error('No se pudo eliminar el tema.');
  }

  async fetchCloseRequestedTopics(): Promise<ModerationTopic[]> {
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select('id, forum_id, title, excerpt, author_handle, cover_image_url, created_at')
      .eq('close_status', 'close_requested')
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) throw error;
    return this.filterByForumAccess((data ?? []).map((row) => this.mapTopic(row)));
  }

  async approveTopicClose(topicId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('forum_topics')
      .update({
        close_status: 'closed',
        is_closed: true,
        is_resolved: true,
      })
      .eq('id', topicId);
    if (error) throw error;
  }

  async rejectTopicClose(topicId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('forum_topics')
      .update({ close_status: 'open' })
      .eq('id', topicId);
    if (error) throw error;
  }

  async fetchPendingEvents(): Promise<PendingEvent[]> {
    if (!this.auth.isAdmin()) return [];
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .select(
        'id, title, subtitle, event_type, starts_at, created_at, profiles!created_by(handle)',
      )
      .eq('status', 'pending_review')
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) throw error;
    return (data ?? []).map((row) => {
      const profiles = row.profiles as { handle?: string } | null;
      return {
        id: String(row.id),
        title: String(row.title ?? ''),
        subtitle: (row.subtitle as string | null) ?? null,
        eventType: (row.event_type as string | null) ?? null,
        startsAt: String(row.starts_at ?? ''),
        createdAt: String(row.created_at ?? ''),
        createdByHandle: profiles?.handle ?? null,
      };
    });
  }

  async publishEvent(eventId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('calendar_events')
      .update({ status: 'published' })
      .eq('id', eventId);
    if (error) throw error;
  }

  async rejectEvent(eventId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('calendar_events')
      .delete()
      .eq('id', eventId);
    if (error) throw error;
  }

  async fetchPendingReportGroups(): Promise<ModerationReportGroup[]> {
    const { data, error } = await getSupabase()
      .from('reports')
      .select('id, target_type, target_id, reason, details, created_at, reporter_id, profiles!reporter_id(handle)')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(100);
    if (error) throw error;

    const raw = (data ?? []).map((row) => {
      const profiles = row.profiles as { handle?: string } | null;
      return {
        id: String(row.id),
        targetType: String(row.target_type ?? ''),
        targetId: String(row.target_id ?? ''),
        reason: String(row.reason ?? ''),
        details: String(row.details ?? ''),
        createdAt: String(row.created_at ?? ''),
        reporterHandle: profiles?.handle ?? null,
        targetLabel: String(row.target_id ?? ''),
        targetForumId: null as string | null,
        authorProfileId: null as string | null,
      } satisfies ModerationReportItem;
    });

    const enriched = await this.enrichReports(raw);
    // Profile reports: solo admin (sin forum_id). Temas/respuestas: admin o mod del foro.
    const scoped = this.auth.isAdmin()
      ? enriched
      : enriched.filter((r) => {
          if (r.targetType === 'profile') return false;
          const forum = r.targetForumId;
          return !!forum && this.auth.moderatedForumIds().has(forum);
        });

    return this.groupReports(scoped);
  }

  async resolveReportsForTarget(targetType: string, targetId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('reports')
      .update({ status: 'resolved' })
      .eq('target_type', targetType)
      .eq('target_id', targetId)
      .eq('status', 'pending');
    if (error) throw error;
  }

  async suspendProfile(profileId: string, reason: string): Promise<void> {
    const { error } = await getSupabase()
      .from('profiles')
      .update({
        suspended_at: new Date().toISOString(),
        suspended_reason: reason.trim(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', profileId);
    if (error) throw error;
  }

  private async enrichReports(
    reports: ModerationReportItem[],
  ): Promise<ModerationReportItem[]> {
    if (!reports.length) return reports;
    const client = getSupabase();

    const profileIds = [
      ...new Set(
        reports.filter((r) => r.targetType === 'profile').map((r) => r.targetId),
      ),
    ];
    const topicIds = [
      ...new Set(
        reports.filter((r) => r.targetType === 'topic').map((r) => r.targetId),
      ),
    ];
    const replyIds = [
      ...new Set(
        reports.filter((r) => r.targetType === 'reply').map((r) => r.targetId),
      ),
    ];

    const handles = new Map<string, string>();
    if (profileIds.length) {
      const { data } = await client
        .from('profiles')
        .select('id, handle')
        .in('id', profileIds);
      for (const row of data ?? []) {
        handles.set(String(row.id), String(row.handle ?? ''));
      }
    }

    const topics = new Map<string, { title: string; forumId: string; authorId: string }>();
    if (topicIds.length) {
      const { data } = await client
        .from('forum_topics')
        .select('id, title, forum_id, author_id')
        .in('id', topicIds);
      for (const row of data ?? []) {
        topics.set(String(row.id), {
          title: String(row.title ?? 'Tema reportado'),
          forumId: String(row.forum_id ?? ''),
          authorId: String(row.author_id ?? ''),
        });
      }
    }

    const replies = new Map<
      string,
      { preview: string; forumId: string | null; authorId: string | null; topicTitle: string | null }
    >();
    if (replyIds.length) {
      const { data } = await client
        .from('forum_replies')
        .select('id, content, topic_id, author_id, forum_topics(forum_id, title)')
        .in('id', replyIds);
      for (const row of data ?? []) {
        const ft = row.forum_topics as { forum_id?: string; title?: string } | null;
        const content = String(row.content ?? '').trim();
        replies.set(String(row.id), {
          preview: content.length > 80 ? `${content.slice(0, 80)}…` : content || 'Respuesta reportada',
          forumId: ft?.forum_id ?? null,
          authorId: (row.author_id as string | null) ?? null,
          topicTitle: ft?.title ?? null,
        });
      }
    }

    return reports.map((report) => {
      if (report.targetType === 'profile') {
        const handle = handles.get(report.targetId);
        return {
          ...report,
          targetLabel: handle ? `@${handle}` : 'Perfil reportado',
          authorProfileId: report.targetId,
          targetForumId: null,
        };
      }
      if (report.targetType === 'topic') {
        const topic = topics.get(report.targetId);
        return {
          ...report,
          targetLabel: topic?.title ?? 'Tema reportado',
          targetForumId: topic?.forumId ?? null,
          authorProfileId: topic?.authorId ?? null,
        };
      }
      if (report.targetType === 'reply') {
        const reply = replies.get(report.targetId);
        return {
          ...report,
          targetLabel: reply?.preview ?? 'Respuesta reportada',
          targetForumId: reply?.forumId ?? null,
          authorProfileId: reply?.authorId ?? null,
        };
      }
      return report;
    });
  }

  private groupReports(reports: ModerationReportItem[]): ModerationReportGroup[] {
    const map = new Map<string, ModerationReportItem[]>();
    for (const report of reports) {
      const key = `${report.targetType}:${report.targetId}`;
      const list = map.get(key) ?? [];
      list.push(report);
      map.set(key, list);
    }

    const groups: ModerationReportGroup[] = [];
    for (const list of map.values()) {
      const reasons = [...new Set(list.map((r) => r.reason).filter(Boolean))];
      groups.push({
        targetType: list[0].targetType,
        targetId: list[0].targetId,
        targetLabel: list[0].targetLabel,
        targetForumId: list[0].targetForumId,
        authorProfileId: list[0].authorProfileId,
        reasonsSummary: reasons.join(', '),
        latestAt: list[0].createdAt,
        reports: list,
      });
    }
    return groups;
  }

  private mapTopic(row: Record<string, unknown>): ModerationTopic {
    return {
      id: String(row['id'] ?? ''),
      forumId: String(row['forum_id'] ?? ''),
      title: String(row['title'] ?? ''),
      excerpt: String(row['excerpt'] ?? ''),
      authorHandle: (row['author_handle'] as string | null) ?? null,
      coverImageUrl: (row['cover_image_url'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
      rejectionReason: (row['rejection_reason'] as string | null) ?? null,
      rejectedAt: (row['rejected_at'] as string | null) ?? null,
    };
  }
}
