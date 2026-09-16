import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { getSupabase } from '../supabase.client';
import {
  NOTICIAS_FORUM_ID,
  NewsDraftInput,
  NewsTopic,
  ScheduledNews,
} from './news.models';
import { makePlainExcerpt } from '../../shared/forum-markdown';

@Injectable({ providedIn: 'root' })
export class NewsService {
  private readonly auth = inject(AuthService);

  canManageNoticias(): boolean {
    if (this.auth.isAdmin()) return true;
    return this.auth.moderatedForumIds().has(NOTICIAS_FORUM_ID);
  }

  async listPublished(limit = 40): Promise<NewsTopic[]> {
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select(
        'id, title, excerpt, body, author_handle, status, related_forum_id, cover_image_url, created_at, comment_count',
      )
      .eq('forum_id', NOTICIAS_FORUM_ID)
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapTopic(row as Record<string, unknown>));
  }

  async listScheduled(limit = 40): Promise<ScheduledNews[]> {
    const { data, error } = await getSupabase()
      .from('noticias_scheduled')
      .select(
        'id, title, excerpt, body, author_handle, related_forum_id, cover_image_url, scheduled_at, status, published_topic_id, created_at',
      )
      .in('status', ['scheduled', 'published', 'cancelled'])
      .order('scheduled_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapScheduled(row as Record<string, unknown>));
  }

  async publishNow(input: NewsDraftInput): Promise<NewsTopic> {
    if (!this.canManageNoticias()) {
      throw new Error('No tienes permiso para publicar noticias.');
    }
    const profile = this.auth.profile();
    const user = this.auth.user();
    if (!profile || !user) throw new Error('Sesión no válida.');

    const title = input.title.trim();
    const body = input.body.trim();
    if (title.length < 2) throw new Error('El título debe tener al menos 2 caracteres.');
    if (body.length < 1) throw new Error('El cuerpo no puede estar vacío.');

    const excerpt = makePlainExcerpt(body);
    const topicId = this.topicIdFromTitle(title);
    const related = input.relatedForumId?.trim() || null;

    const { data, error } = await getSupabase()
      .from('forum_topics')
      .insert({
        id: topicId,
        forum_id: NOTICIAS_FORUM_ID,
        author_id: user.id,
        author_handle: profile.handle?.startsWith('@')
          ? profile.handle
          : `@${profile.handle || 'junta'}`,
        title,
        excerpt,
        body,
        cover_image_url: input.coverImageUrl?.trim() || null,
        related_forum_id: related,
        status: 'pending',
      })
      .select(
        'id, title, excerpt, body, author_handle, status, related_forum_id, cover_image_url, created_at, comment_count',
      )
      .single();
    if (error) throw error;
    const topic = this.mapTopic(data as Record<string, unknown>);
    await this.refreshNoticiasStats();
    return topic;
  }

  async schedule(input: NewsDraftInput): Promise<ScheduledNews> {
    if (!this.canManageNoticias()) {
      throw new Error('No tienes permiso para programar noticias.');
    }
    const profile = this.auth.profile();
    const user = this.auth.user();
    if (!profile || !user) throw new Error('Sesión no válida.');

    const title = input.title.trim();
    const body = input.body.trim();
    const scheduledAt = input.scheduledAt?.trim();
    if (title.length < 2) throw new Error('El título debe tener al menos 2 caracteres.');
    if (body.length < 1) throw new Error('El cuerpo no puede estar vacío.');
    if (!scheduledAt) throw new Error('Indica fecha y hora de publicación.');

    const when = new Date(scheduledAt);
    if (Number.isNaN(when.getTime())) {
      throw new Error('Fecha de programación no válida.');
    }
    if (when.getTime() < Date.now() + 2 * 60 * 1000) {
      throw new Error('Programa al menos 2 minutos en el futuro.');
    }

    const { data, error } = await getSupabase()
      .from('noticias_scheduled')
      .insert({
        author_id: user.id,
        author_handle: profile.handle?.startsWith('@')
          ? profile.handle
          : `@${profile.handle || 'junta'}`,
        title,
        excerpt: makePlainExcerpt(body),
        body,
        cover_image_url: input.coverImageUrl?.trim() || null,
        related_forum_id: input.relatedForumId?.trim() || null,
        scheduled_at: when.toISOString(),
        status: 'scheduled',
      })
      .select(
        'id, title, excerpt, body, author_handle, related_forum_id, cover_image_url, scheduled_at, status, published_topic_id, created_at',
      )
      .single();
    if (error) throw error;
    return this.mapScheduled(data as Record<string, unknown>);
  }

  async updatePublished(topicId: string, input: NewsDraftInput): Promise<NewsTopic> {
    if (!this.canManageNoticias()) {
      throw new Error('No tienes permiso para editar noticias.');
    }
    const title = input.title.trim();
    const body = input.body.trim();
    if (title.length < 2) throw new Error('El título debe tener al menos 2 caracteres.');
    if (body.length < 1) throw new Error('El cuerpo no puede estar vacío.');

    const { data, error } = await getSupabase()
      .from('forum_topics')
      .update({
        title,
        excerpt: makePlainExcerpt(body),
        body,
        cover_image_url: input.coverImageUrl?.trim() || null,
        related_forum_id: input.relatedForumId?.trim() || null,
        edited_at: new Date().toISOString(),
      })
      .eq('id', topicId)
      .eq('forum_id', NOTICIAS_FORUM_ID)
      .select(
        'id, title, excerpt, body, author_handle, status, related_forum_id, cover_image_url, created_at, comment_count',
      )
      .maybeSingle();
    if (error) throw error;
    if (!data) throw new Error('No se pudo actualizar la noticia.');
    return this.mapTopic(data as Record<string, unknown>);
  }

  async updateScheduled(id: string, input: NewsDraftInput): Promise<ScheduledNews> {
    if (!this.canManageNoticias()) {
      throw new Error('No tienes permiso para editar noticias programadas.');
    }
    const title = input.title.trim();
    const body = input.body.trim();
    const scheduledAt = input.scheduledAt?.trim();
    if (title.length < 2) throw new Error('El título debe tener al menos 2 caracteres.');
    if (body.length < 1) throw new Error('El cuerpo no puede estar vacío.');
    if (!scheduledAt) throw new Error('Indica fecha y hora de publicación.');

    const when = new Date(scheduledAt);
    if (Number.isNaN(when.getTime())) {
      throw new Error('Fecha de programación no válida.');
    }
    if (when.getTime() < Date.now() + 2 * 60 * 1000) {
      throw new Error('Programa al menos 2 minutos en el futuro.');
    }

    const { data, error } = await getSupabase()
      .from('noticias_scheduled')
      .update({
        title,
        excerpt: makePlainExcerpt(body),
        body,
        cover_image_url: input.coverImageUrl?.trim() || null,
        related_forum_id: input.relatedForumId?.trim() || null,
        scheduled_at: when.toISOString(),
        status: 'scheduled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .eq('status', 'scheduled')
      .select(
        'id, title, excerpt, body, author_handle, related_forum_id, cover_image_url, scheduled_at, status, published_topic_id, created_at',
      )
      .maybeSingle();
    if (error) throw error;
    if (!data) throw new Error('No se pudo actualizar (¿ya no está programada?).');
    return this.mapScheduled(data as Record<string, unknown>);
  }

  async deletePublished(topicId: string): Promise<void> {
    if (!this.canManageNoticias()) {
      throw new Error('No tienes permiso para eliminar noticias.');
    }
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .delete()
      .eq('id', topicId)
      .eq('forum_id', NOTICIAS_FORUM_ID)
      .select('id');
    if (error) throw error;
    if (!data?.length) throw new Error('No se pudo eliminar la noticia.');
    await this.refreshNoticiasStats();
  }

  private async refreshNoticiasStats(): Promise<void> {
    const { error } = await getSupabase().rpc('refresh_forum_pillar_stats', {
      p_forum_id: NOTICIAS_FORUM_ID,
    });
    if (error) {
      console.warn('No se pudieron refrescar stats del foro Noticias', error);
    }
  }

  async cancelScheduled(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('noticias_scheduled')
      .update({ status: 'cancelled', updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('status', 'scheduled');
    if (error) throw error;
  }

  async deleteScheduled(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('noticias_scheduled')
      .delete()
      .eq('id', id)
      .in('status', ['scheduled', 'cancelled']);
    if (error) throw error;
  }

  async publishDueNow(): Promise<number> {
    const { data, error } = await getSupabase().rpc(
      'publish_due_noticias_scheduled',
    );
    if (error) throw error;
    return Number(data ?? 0);
  }

  async uploadCover(file: File): Promise<string> {
    if (!file.type.startsWith('image/')) {
      throw new Error('El archivo debe ser una imagen.');
    }
    if (file.size > 3 * 1024 * 1024) {
      throw new Error('La portada no puede superar 3 MB.');
    }
    const stamp = Date.now().toString(36);
    const path = `noticias/${stamp}-cover.jpg`;
    const { error } = await getSupabase().storage.from('topic-covers').upload(path, file, {
      upsert: true,
      contentType: file.type || 'image/jpeg',
    });
    if (error) throw error;
    const { data } = getSupabase().storage.from('topic-covers').getPublicUrl(path);
    return data.publicUrl;
  }

  relatedLabel(id: string | null): string {
    if (!id) return 'Sin etiqueta';
    switch (id) {
      case 'foro-cofradiero':
        return 'Círculo Cofrade';
      case 'pentagrama-cofrade':
        return 'Pentagrama';
      case 'martillo-trabajadera':
        return 'Martillo';
      case 'hermandades':
        return 'Hermandades';
      default:
        return id;
    }
  }

  private topicIdFromTitle(title: string): string {
    let slug = title
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
    if (!slug) slug = 'noticia';
    if (slug.length > 40) slug = slug.slice(0, 40);
    return `${slug}-${Date.now().toString(36)}`;
  }

  private mapTopic(row: Record<string, unknown>): NewsTopic {
    return {
      id: String(row['id'] ?? ''),
      title: String(row['title'] ?? ''),
      excerpt: String(row['excerpt'] ?? ''),
      body: String(row['body'] ?? ''),
      authorHandle: (row['author_handle'] as string | null) ?? null,
      status: String(row['status'] ?? 'published'),
      relatedForumId: (row['related_forum_id'] as string | null) ?? null,
      coverImageUrl: (row['cover_image_url'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
      commentCount: Number(row['comment_count'] ?? 0),
    };
  }

  private mapScheduled(row: Record<string, unknown>): ScheduledNews {
    return {
      id: String(row['id'] ?? ''),
      title: String(row['title'] ?? ''),
      excerpt: String(row['excerpt'] ?? ''),
      body: String(row['body'] ?? ''),
      authorHandle: String(row['author_handle'] ?? ''),
      relatedForumId: (row['related_forum_id'] as string | null) ?? null,
      coverImageUrl: (row['cover_image_url'] as string | null) ?? null,
      scheduledAt: String(row['scheduled_at'] ?? ''),
      status: String(row['status'] ?? 'scheduled') as ScheduledNews['status'],
      publishedTopicId: (row['published_topic_id'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
    };
  }
}
