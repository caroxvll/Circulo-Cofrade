import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { getSupabase } from '../supabase.client';
import {
  ConversationForum,
  ConversationReply,
  ConversationTopic,
  ConversationTopicStatus,
} from './conversations.models';

@Injectable({ providedIn: 'root' })
export class ConversationsService {
  private readonly auth = inject(AuthService);

  canModerateForum(forumId: string): boolean {
    if (this.auth.isAdmin()) return true;
    return this.auth.moderatedForumIds().has(forumId);
  }

  async listForums(): Promise<ConversationForum[]> {
    const { data, error } = await getSupabase()
      .from('forum_pillars')
      .select('id, name, description, topic_count, message_count, is_enabled, sort_order')
      .order('sort_order', { ascending: true });
    if (error) throw error;

    const rows = (data ?? []).map((row) => ({
      id: String(row['id'] ?? ''),
      name: String(row['name'] ?? ''),
      description: String(row['description'] ?? ''),
      topicCount: Number(row['topic_count'] ?? 0),
      messageCount: Number(row['message_count'] ?? 0),
      isEnabled: Boolean(row['is_enabled'] ?? true),
    }));

    if (this.auth.isAdmin()) return rows;
    const allowed = this.auth.moderatedForumIds();
    return rows.filter((f) => allowed.has(f.id));
  }

  async listTopics(
    forumId: string,
    opts: {
      status?: ConversationTopicStatus;
      search?: string;
      limit?: number;
    } = {},
  ): Promise<ConversationTopic[]> {
    if (!this.canModerateForum(forumId)) return [];

    const status = opts.status ?? 'published';
    const limit = opts.limit ?? 80;
    let req = getSupabase()
      .from('forum_topics')
      .select(
        'id, forum_id, title, excerpt, body, author_handle, author_id, status, comment_count, view_count, is_closed, is_pinned, is_system, season_key, created_at',
      )
      .eq('forum_id', forumId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (status !== 'all') {
      req = req.eq('status', status);
    }

    const search = opts.search?.replace(/[%_]/g, '').trim();
    if (search) {
      req = req.or(
        `title.ilike.%${search}%,excerpt.ilike.%${search}%,author_handle.ilike.%${search}%`,
      );
    }

    const { data, error } = await req;
    if (error) throw error;
    return (data ?? []).map((row) => this.mapTopic(row as Record<string, unknown>));
  }

  async getTopic(forumId: string, topicId: string): Promise<ConversationTopic | null> {
    if (!this.canModerateForum(forumId)) return null;
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select(
        'id, forum_id, title, excerpt, body, author_handle, author_id, status, comment_count, view_count, is_closed, is_pinned, is_system, season_key, created_at',
      )
      .eq('forum_id', forumId)
      .eq('id', topicId)
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    return this.mapTopic(data as Record<string, unknown>);
  }

  async listReplies(topicId: string, limit = 100): Promise<ConversationReply[]> {
    const { data, error } = await getSupabase()
      .from('forum_replies')
      .select(
        'id, topic_id, author_id, author_handle, content, created_at, parent_reply_id, deleted_at, deleted_by',
      )
      .eq('topic_id', topicId)
      .order('created_at', { ascending: true })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapReply(row as Record<string, unknown>));
  }

  async closeTopic(topicId: string): Promise<void> {
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

  async reopenTopic(topicId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('forum_topics')
      .update({
        close_status: 'open',
        is_closed: false,
        is_resolved: false,
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

  async softDeleteReply(replyId: string): Promise<void> {
    const { error } = await getSupabase().rpc('soft_delete_forum_reply', {
      p_reply_id: replyId,
    });
    if (error) throw error;
  }

  async hardDeleteReply(replyId: string): Promise<void> {
    const { error } = await getSupabase().rpc('hard_delete_forum_reply', {
      p_reply_id: replyId,
    });
    if (error) {
      const code = String((error as { message?: string }).message ?? '');
      if (code.includes('not_soft_deleted')) {
        throw new Error('Solo se pueden borrar del todo respuestas ya ocultas.');
      }
      if (code.includes('forbidden')) {
        throw new Error('No tienes permiso para borrar esta respuesta.');
      }
      throw error;
    }
  }

  private mapTopic(row: Record<string, unknown>): ConversationTopic {
    return {
      id: String(row['id'] ?? ''),
      forumId: String(row['forum_id'] ?? ''),
      title: String(row['title'] ?? ''),
      excerpt: String(row['excerpt'] ?? ''),
      body: String(row['body'] ?? ''),
      authorHandle: (row['author_handle'] as string | null) ?? null,
      authorId: (row['author_id'] as string | null) ?? null,
      status: String(row['status'] ?? 'published'),
      commentCount: Number(row['comment_count'] ?? 0),
      viewCount: Number(row['view_count'] ?? 0),
      isClosed: Boolean(row['is_closed'] ?? false),
      isPinned: Boolean(row['is_pinned'] ?? false),
      isSystem: Boolean(row['is_system'] ?? false),
      seasonKey: (row['season_key'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
      lastActivityAt: (row['created_at'] as string | null) ?? null,
    };
  }

  private mapReply(row: Record<string, unknown>): ConversationReply {
    return {
      id: String(row['id'] ?? ''),
      topicId: String(row['topic_id'] ?? ''),
      authorId: (row['author_id'] as string | null) ?? null,
      authorHandle: (row['author_handle'] as string | null) ?? null,
      content: String(row['content'] ?? ''),
      createdAt: String(row['created_at'] ?? ''),
      parentReplyId: (row['parent_reply_id'] as string | null) ?? null,
      deletedAt: (row['deleted_at'] as string | null) ?? null,
      deletedBy: (row['deleted_by'] as string | null) ?? null,
    };
  }
}
