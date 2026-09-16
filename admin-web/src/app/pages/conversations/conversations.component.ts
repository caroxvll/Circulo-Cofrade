import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { RealtimeChannel } from '@supabase/supabase-js';
import { AuthService } from '../../core/auth/auth.service';
import {
  ConversationForum,
  ConversationReply,
  ConversationTopic,
  ConversationTopicStatus,
} from '../../core/conversations/conversations.models';
import { ConversationsService } from '../../core/conversations/conversations.service';
import { getSupabase } from '../../core/supabase.client';
import { formatDateTime, formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-conversations-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './conversations.component.html',
  styleUrl: './conversations.component.scss',
})
export class ConversationsPageComponent implements OnInit, OnDestroy {
  private readonly api = inject(ConversationsService);
  private readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private forumChannel: RealtimeChannel | null = null;
  private threadChannel: RealtimeChannel | null = null;
  private topicsRefreshTimer: ReturnType<typeof setTimeout> | null = null;
  private threadRefreshTimer: ReturnType<typeof setTimeout> | null = null;

  readonly forums = signal<ConversationForum[]>([]);
  readonly topics = signal<ConversationTopic[]>([]);
  readonly replies = signal<ConversationReply[]>([]);
  readonly selectedForumId = signal<string | null>(null);
  readonly selectedTopic = signal<ConversationTopic | null>(null);
  readonly loadingForums = signal(true);
  readonly loadingTopics = signal(false);
  readonly loadingThread = signal(false);
  readonly busyId = signal<string | null>(null);
  readonly error = signal<string | null>(null);
  readonly statusFilter = signal<ConversationTopicStatus>('published');

  topicSearch = '';

  readonly timeAgo = formatTimeAgo;
  readonly dateTime = formatDateTime;
  readonly isAdmin = this.auth.isAdmin;

  readonly selectedForum = computed(() => {
    const id = this.selectedForumId();
    return this.forums().find((f) => f.id === id) ?? null;
  });

  readonly visibleReplies = computed(() => this.replies());

  ngOnInit(): void {
    void this.bootstrap();
  }

  ngOnDestroy(): void {
    this.teardownRealtime();
  }

  private async bootstrap(): Promise<void> {
    this.loadingForums.set(true);
    this.error.set(null);
    try {
      const forums = await this.api.listForums();
      this.forums.set(forums);
      const qForum = this.route.snapshot.queryParamMap.get('forum');
      const qTopic = this.route.snapshot.queryParamMap.get('topic');
      const initial =
        (qForum && forums.some((f) => f.id === qForum) ? qForum : null) ??
        forums[0]?.id ??
        null;
      if (initial) {
        await this.selectForum(initial, false);
        if (qTopic) {
          await this.openTopic(qTopic);
        }
      }
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo cargar'));
    } finally {
      this.loadingForums.set(false);
    }
  }

  async selectForum(forumId: string, clearTopic = true): Promise<void> {
    this.selectedForumId.set(forumId);
    if (clearTopic) {
      this.selectedTopic.set(null);
      this.replies.set([]);
      this.unbindThreadRealtime();
    }
    this.syncQuery(forumId, clearTopic ? null : this.selectedTopic()?.id ?? null);
    this.bindForumRealtime(forumId);
    await this.reloadTopics();
  }

  setStatusFilter(status: ConversationTopicStatus): void {
    this.statusFilter.set(status);
    void this.reloadTopics();
  }

  searchTopics(): void {
    void this.reloadTopics();
  }

  async reloadTopics(): Promise<void> {
    const forumId = this.selectedForumId();
    if (!forumId) return;
    this.loadingTopics.set(true);
    this.error.set(null);
    try {
      this.topics.set(
        await this.api.listTopics(forumId, {
          status: this.statusFilter(),
          search: this.topicSearch,
        }),
      );
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudieron cargar temas'));
    } finally {
      this.loadingTopics.set(false);
    }
  }

  async openTopic(topicId: string): Promise<void> {
    const forumId = this.selectedForumId();
    if (!forumId) return;
    this.loadingThread.set(true);
    this.error.set(null);
    try {
      const topic = await this.api.getTopic(forumId, topicId);
      if (!topic) {
        this.error.set('Tema no encontrado');
        this.selectedTopic.set(null);
        this.replies.set([]);
        return;
      }
      this.selectedTopic.set(topic);
      this.replies.set(await this.api.listReplies(topicId));
      this.syncQuery(forumId, topicId);
      this.bindThreadRealtime(topicId);
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo abrir el hilo'));
    } finally {
      this.loadingThread.set(false);
    }
  }

  closeThread(): void {
    this.selectedTopic.set(null);
    this.replies.set([]);
    this.unbindThreadRealtime();
    const forumId = this.selectedForumId();
    if (forumId) this.syncQuery(forumId, null);
  }

  async closeTopic(): Promise<void> {
    const topic = this.selectedTopic();
    if (!topic) return;
    if (!confirm(`¿Cerrar el tema «${topic.title}»?`)) return;
    this.busyId.set(topic.id);
    try {
      await this.api.closeTopic(topic.id);
      await this.openTopic(topic.id);
      await this.reloadTopics();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo cerrar'));
    } finally {
      this.busyId.set(null);
    }
  }

  async reopenTopic(): Promise<void> {
    const topic = this.selectedTopic();
    if (!topic) return;
    this.busyId.set(topic.id);
    try {
      await this.api.reopenTopic(topic.id);
      await this.openTopic(topic.id);
      await this.reloadTopics();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo reabrir'));
    } finally {
      this.busyId.set(null);
    }
  }

  async deleteTopic(): Promise<void> {
    const topic = this.selectedTopic();
    if (!topic) return;
    if (
      !confirm(
        `¿Eliminar definitivamente «${topic.title}» y todas sus respuestas?`,
      )
    ) {
      return;
    }
    this.busyId.set(topic.id);
    try {
      await this.api.deleteTopic(topic.id);
      this.closeThread();
      await this.reloadTopics();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo eliminar'));
    } finally {
      this.busyId.set(null);
    }
  }

  async hideReply(reply: ConversationReply): Promise<void> {
    if (reply.deletedAt) return;
    if (!confirm('¿Ocultar esta respuesta? Seguirá visible aquí para moderación.')) {
      return;
    }
    this.busyId.set(reply.id);
    try {
      await this.api.softDeleteReply(reply.id);
      const topic = this.selectedTopic();
      if (topic) {
        this.replies.set(await this.api.listReplies(topic.id));
        await this.reloadTopics();
      }
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo ocultar la respuesta'));
    } finally {
      this.busyId.set(null);
    }
  }

  async purgeReply(reply: ConversationReply): Promise<void> {
    if (!reply.deletedAt) return;
    if (
      !confirm(
        '¿Borrar definitivamente esta respuesta oculta? Esta acción no se puede deshacer.',
      )
    ) {
      return;
    }
    this.busyId.set(reply.id);
    try {
      await this.api.hardDeleteReply(reply.id);
      const topic = this.selectedTopic();
      if (topic) {
        this.replies.set(await this.api.listReplies(topic.id));
        await this.reloadTopics();
      }
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo borrar la respuesta'));
    } finally {
      this.busyId.set(null);
    }
  }

  handleLabel(handle: string | null): string {
    if (!handle) return '@—';
    return handle.startsWith('@') ? handle : `@${handle}`;
  }

  statusLabel(status: string): string {
    switch (status) {
      case 'published':
        return 'Publicado';
      case 'pending':
        return 'Pendiente';
      case 'rejected':
        return 'Rechazado';
      default:
        return status;
    }
  }

  private bindForumRealtime(forumId: string): void {
    if (this.forumChannel) {
      void getSupabase().removeChannel(this.forumChannel);
      this.forumChannel = null;
    }
    this.forumChannel = getSupabase()
      .channel(`admin-conv-topics-${forumId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'forum_topics',
          filter: `forum_id=eq.${forumId}`,
        },
        () => this.scheduleTopicsRefresh(),
      )
      .subscribe();
  }

  private bindThreadRealtime(topicId: string): void {
    this.unbindThreadRealtime();
    this.threadChannel = getSupabase()
      .channel(`admin-conv-thread-${topicId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'forum_replies',
          filter: `topic_id=eq.${topicId}`,
        },
        () => this.scheduleThreadRefresh(topicId),
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'forum_topics',
          filter: `id=eq.${topicId}`,
        },
        () => this.scheduleThreadRefresh(topicId),
      )
      .subscribe();
  }

  private unbindThreadRealtime(): void {
    if (this.threadRefreshTimer) {
      clearTimeout(this.threadRefreshTimer);
      this.threadRefreshTimer = null;
    }
    if (this.threadChannel) {
      void getSupabase().removeChannel(this.threadChannel);
      this.threadChannel = null;
    }
  }

  private teardownRealtime(): void {
    if (this.topicsRefreshTimer) {
      clearTimeout(this.topicsRefreshTimer);
      this.topicsRefreshTimer = null;
    }
    this.unbindThreadRealtime();
    if (this.forumChannel) {
      void getSupabase().removeChannel(this.forumChannel);
      this.forumChannel = null;
    }
  }

  private scheduleTopicsRefresh(): void {
    if (this.topicsRefreshTimer) clearTimeout(this.topicsRefreshTimer);
    this.topicsRefreshTimer = setTimeout(() => {
      void this.reloadTopics();
    }, 120);
  }

  private scheduleThreadRefresh(topicId: string): void {
    if (this.selectedTopic()?.id !== topicId) return;
    if (this.threadRefreshTimer) clearTimeout(this.threadRefreshTimer);
    this.threadRefreshTimer = setTimeout(() => {
      void this.refreshOpenThread(topicId);
    }, 80);
  }

  private async refreshOpenThread(topicId: string): Promise<void> {
    const forumId = this.selectedForumId();
    if (!forumId || this.selectedTopic()?.id !== topicId) return;
    try {
      const topic = await this.api.getTopic(forumId, topicId);
      if (!topic) {
        this.closeThread();
        await this.reloadTopics();
        return;
      }
      this.selectedTopic.set(topic);
      this.replies.set(await this.api.listReplies(topicId));
      await this.reloadTopics();
    } catch {
      /* mantener vista actual */
    }
  }

  private errMsg(err: unknown, fallback: string): string {
    if (err instanceof Error && err.message) return err.message;
    if (
      err &&
      typeof err === 'object' &&
      'message' in err &&
      typeof (err as { message: unknown }).message === 'string' &&
      (err as { message: string }).message
    ) {
      return (err as { message: string }).message;
    }
    return fallback;
  }

  private syncQuery(forumId: string, topicId: string | null): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: {
        forum: forumId,
        topic: topicId || null,
      },
      queryParamsHandling: 'merge',
      replaceUrl: true,
    });
  }
}
