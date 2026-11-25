import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';
import {
  HermandadTopicOption,
  parseHermandadTopicTitle,
} from '../community/community.service';

export interface XIngestSettings {
  enabled: boolean;
  intervalMinutes: number;
  maxPostsPerAccount: number;
  lastRunAt: string | null;
  lastRunStatus: string | null;
  lastRunError: string | null;
  lastRunNewPosts: number;
  lastRunAccounts: number;
  lastRunForced: boolean;
}

export interface XIngestAccount {
  id: string;
  topicId: string;
  handle: string;
  ingestEnabled: boolean;
  lastError: string | null;
  lastPulledAt: string | null;
  lastCapped: boolean;
  topicTitle: string | null;
  hermandadName: string;
}

export interface XIngestDraft {
  id: string;
  accountId: string;
  topicId: string;
  handle: string;
  xPostId: string;
  body: string;
  status: string;
  suggestedCategory: string;
  sourceUrl: string | null;
  media: Array<Record<string, string>>;
  postedAt: string | null;
  topicTitle: string | null;
  hermandadName: string;
  processionDay: string | null;
  imageUrl: string | null;
}

export interface XIngestRunResult {
  skipped?: boolean;
  reason?: string;
  message?: string;
  newPosts?: number;
  accounts?: number;
  skipBacklog?: boolean;
  errors?: string[];
}

const INTERVALS = [15, 30, 60, 120, 360];

@Injectable({ providedIn: 'root' })
export class XIngestService {
  readonly intervals = INTERVALS;

  async fetchSettings(): Promise<XIngestSettings> {
    const { data, error } = await getSupabase()
      .from('x_ingest_settings')
      .select(
        'enabled, interval_minutes, max_posts_per_account, last_run_at, last_run_status, last_run_error, last_run_new_posts, last_run_accounts, last_run_forced',
      )
      .eq('id', 1)
      .maybeSingle();
    if (error) throw error;
    if (!data) throw new Error('Falta x_ingest.sql en este proyecto');
    return {
      enabled: data.enabled === true,
      intervalMinutes: Number(data.interval_minutes ?? 60),
      maxPostsPerAccount: Number(data.max_posts_per_account ?? 8),
      lastRunAt: (data.last_run_at as string | null) ?? null,
      lastRunStatus: (data.last_run_status as string | null) ?? null,
      lastRunError: (data.last_run_error as string | null) ?? null,
      lastRunNewPosts: Number(data.last_run_new_posts ?? 0),
      lastRunAccounts: Number(data.last_run_accounts ?? 0),
      lastRunForced: data.last_run_forced === true,
    };
  }

  async saveSettings(input: {
    enabled: boolean;
    intervalMinutes: number;
    maxPostsPerAccount: number;
  }): Promise<void> {
    const { error } = await getSupabase()
      .from('x_ingest_settings')
      .update({
        enabled: input.enabled,
        interval_minutes: input.intervalMinutes,
        max_posts_per_account: input.maxPostsPerAccount,
        updated_at: new Date().toISOString(),
      })
      .eq('id', 1);
    if (error) throw error;
  }

  async fetchAccounts(): Promise<XIngestAccount[]> {
    const { data, error } = await getSupabase()
      .from('x_ingest_accounts')
      .select('id, topic_id, handle, ingest_enabled, last_error, last_pulled_at, last_capped, forum_topics(title)')
      .order('handle');
    if (error) throw error;
    return (data ?? []).map((row) => {
      const topic = row.forum_topics as { title?: string } | null;
      const title = topic?.title ?? null;
      return {
        id: String(row.id),
        topicId: String(row.topic_id),
        handle: String(row.handle),
        ingestEnabled: row.ingest_enabled !== false,
        lastError: (row.last_error as string | null) ?? null,
        lastPulledAt: (row.last_pulled_at as string | null) ?? null,
        lastCapped: row.last_capped === true,
        topicTitle: title,
        hermandadName: title
          ? parseHermandadTopicTitle(title).hermandadName
          : String(row.handle),
      };
    });
  }

  async upsertAccount(input: { topicId: string; handle: string }): Promise<void> {
    const { error } = await getSupabase().from('x_ingest_accounts').upsert(
      {
        topic_id: input.topicId,
        handle: input.handle.replace(/^@+/, '').trim(),
      },
      { onConflict: 'topic_id' },
    );
    if (error) throw error;
  }

  async setAccountEnabled(id: string, enabled: boolean): Promise<void> {
    const { error } = await getSupabase()
      .from('x_ingest_accounts')
      .update({ ingest_enabled: enabled })
      .eq('id', id);
    if (error) throw error;
  }

  async deleteAccount(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('x_ingest_accounts')
      .delete()
      .eq('id', id);
    if (error) throw error;
  }

  async fetchDrafts(): Promise<XIngestDraft[]> {
    const { data, error } = await getSupabase()
      .from('x_ingest_drafts')
      .select(
        'id, account_id, topic_id, handle, x_post_id, body, status, suggested_category, source_url, media, posted_at, forum_topics(title)',
      )
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(200);
    if (error) throw error;
    return (data ?? []).map((row) => {
      const topic = row.forum_topics as { title?: string } | null;
      const title = topic?.title ?? null;
      const parsed = title ? parseHermandadTopicTitle(title) : null;
      const media = Array.isArray(row.media)
        ? (row.media as Array<Record<string, string>>)
        : [];
      return {
        id: String(row.id),
        accountId: String(row.account_id),
        topicId: String(row.topic_id),
        handle: String(row.handle),
        xPostId: String(row.x_post_id),
        body: String(row.body ?? ''),
        status: String(row.status ?? 'pending'),
        suggestedCategory: String(row.suggested_category ?? 'noticia'),
        sourceUrl: (row.source_url as string | null) ?? null,
        media,
        postedAt: (row.posted_at as string | null) ?? null,
        topicTitle: title,
        hermandadName: parsed?.hermandadName ?? String(row.handle),
        processionDay: parsed?.processionDay ?? null,
        imageUrl: firstMediaUrl(media),
      };
    });
  }

  async discardDraftsForTopic(topicId: string): Promise<number> {
    const { data, error } = await getSupabase()
      .from('x_ingest_drafts')
      .update({
        status: 'discarded',
        reviewed_at: new Date().toISOString(),
      })
      .eq('topic_id', topicId)
      .eq('status', 'pending')
      .select('id');
    if (error) throw error;
    return data?.length ?? 0;
  }

  async runPull(input: {
    force?: boolean;
    skipBacklog?: boolean;
    accountId?: string;
  } = {}): Promise<XIngestRunResult> {
    const { data, error } = await getSupabase().functions.invoke('x-ingest-pull', {
      body: {
        force: input.force !== false,
        skipBacklog: input.skipBacklog === true,
        accountId: input.accountId,
      },
    });
    if (error) throw error;
    const payload = data as Record<string, unknown>;
    if (payload?.['error']) {
      throw new Error(String(payload['error']));
    }
    return payload as XIngestRunResult;
  }

  async publishDraft(input: {
    draftId: string;
    topicId: string;
    category: string;
    body: string;
  }): Promise<void> {
    const { error } = await getSupabase().rpc('x_ingest_publish_draft', {
      p_draft_id: input.draftId,
      p_topic_id: input.topicId,
      p_category: input.category,
      p_body: input.body,
    });
    if (error) throw error;
  }

  async discardDraft(draftId: string): Promise<void> {
    const { error } = await getSupabase().rpc('x_ingest_discard_draft', {
      p_draft_id: draftId,
    });
    if (error) throw error;
  }

  unusedBoards(
    boards: HermandadTopicOption[],
    accounts: XIngestAccount[],
  ): HermandadTopicOption[] {
    const taken = new Set(accounts.map((a) => a.topicId));
    return boards.filter((b) => !taken.has(b.id));
  }
}

function firstMediaUrl(media: Array<Record<string, string>>): string | null {
  for (const item of media) {
    if ((item['type'] === 'photo' || item['type'] === 'image') && item['url']) {
      return item['url'];
    }
  }
  for (const item of media) {
    if (item['previewUrl'] || item['url']) return item['previewUrl'] || item['url'];
  }
  return null;
}
