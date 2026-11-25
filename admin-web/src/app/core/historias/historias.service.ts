import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';

export type HistoriaKind = 'libro' | 'articulo';
export type HistoriaStatus =
  | 'published'
  | 'hidden'
  | 'draft'
  | 'scheduled'
  | 'pending_review';

export const HISTORIA_KIND_OPTIONS: {
  id: HistoriaKind;
  label: string;
  blurb: string;
}[] = [
  {
    id: 'libro',
    label: 'Libro',
    blurb: 'Un relato largo. Varias páginas, se lee como un libro.',
  },
  {
    id: 'articulo',
    label: 'Artículo',
    blurb: 'Una pieza más corta: un tema, un momento, lo que ocurrió.',
  },
];

export interface HistoriaPage {
  body: string;
  image_url?: string;
  caption?: string;
}

export interface HistoriaCommentRow {
  id: string;
  historiaId: string;
  historiaTitle: string;
  userId: string;
  userHandle: string;
  userDisplayName: string;
  body: string;
  createdAt: string;
}

export interface HistoriaRow {
  id: string;
  authorId: string;
  title: string;
  excerpt: string;
  kind: HistoriaKind;
  coverImageUrl: string | null;
  pages: HistoriaPage[];
  status: HistoriaStatus;
  scheduledAt: string | null;
  reviewNote: string | null;
  commentCount: number;
  createdAt: string;
  updatedAt: string;
  authorHandle?: string;
  authorDisplayName?: string;
}

const SELECT =
  'id, author_id, title, excerpt, kind, cover_image_url, pages, status, scheduled_at, review_note, comment_count, created_at, updated_at';
const LIST_SELECT =
  'id, author_id, title, excerpt, kind, cover_image_url, status, scheduled_at, review_note, comment_count, created_at, updated_at';

const KIND_SET = new Set<HistoriaKind>(['libro', 'articulo']);

@Injectable({ providedIn: 'root' })
export class HistoriasService {
  async publishDue(): Promise<void> {
    try {
      await getSupabase().rpc('publish_due_historias');
    } catch {
      /* SQL de programación aún no ejecutado */
    }
  }

  async fetchMine(): Promise<HistoriaRow[]> {
    await this.publishDue();
    const userId = await this.requireUserId();
    const { data, error } = await getSupabase()
      .from('historias')
      .select(LIST_SELECT)
      .eq('author_id', userId)
      .order('updated_at', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapRow(row as Record<string, unknown>));
  }

  async fetchPendingReview(): Promise<HistoriaRow[]> {
    const { data, error } = await getSupabase()
      .from('historias')
      .select(`${LIST_SELECT}, profiles!author_id (handle, display_name)`)
      .eq('status', 'pending_review')
      .order('updated_at', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapRow(row as Record<string, unknown>));
  }

  async setStatus(
    id: string,
    status: HistoriaStatus,
    opts?: { reviewNote?: string | null },
  ): Promise<void> {
    const payload: Record<string, unknown> = {
      status,
      updated_at: new Date().toISOString(),
    };
    if (opts && 'reviewNote' in opts) {
      payload['review_note'] = opts.reviewNote;
    }
    const { error } = await getSupabase()
      .from('historias')
      .update(payload)
      .eq('id', id);
    if (error) throw error;
  }

  async fetchById(id: string): Promise<HistoriaRow | null> {
    await this.publishDue();
    const { data, error } = await getSupabase()
      .from('historias')
      .select(SELECT)
      .eq('id', id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    return this.mapRow(data as Record<string, unknown>);
  }

  async create(input: {
    title: string;
    excerpt: string;
    kind: HistoriaKind;
    pages: HistoriaPage[];
    status: HistoriaStatus;
    coverImageUrl?: string | null;
    scheduledAt?: string | null;
  }): Promise<HistoriaRow> {
    const userId = await this.requireUserId();
    const { data, error } = await getSupabase()
      .from('historias')
      .insert({
        author_id: userId,
        title: input.title.trim(),
        excerpt: input.excerpt.trim(),
        kind: input.kind,
        pages: input.pages,
        status: input.status,
        cover_image_url: input.coverImageUrl ?? null,
        scheduled_at: input.status === 'scheduled' ? input.scheduledAt ?? null : null,
      })
      .select(SELECT)
      .single();
    if (error) throw error;
    return this.mapRow(data as Record<string, unknown>);
  }

  async update(
    id: string,
    input: {
      title: string;
      excerpt: string;
      kind: HistoriaKind;
      pages: HistoriaPage[];
      status: HistoriaStatus;
      coverImageUrl?: string | null;
      scheduledAt?: string | null;
    },
  ): Promise<HistoriaRow> {
    const payload: Record<string, unknown> = {
      title: input.title.trim(),
      excerpt: input.excerpt.trim(),
      kind: input.kind,
      pages: input.pages,
      status: input.status,
      cover_image_url: input.coverImageUrl ?? null,
      scheduled_at: input.status === 'scheduled' ? input.scheduledAt ?? null : null,
      updated_at: new Date().toISOString(),
    };
    if (input.status === 'pending_review' || input.status === 'published') {
      payload['review_note'] = null;
    }
    const { data, error } = await getSupabase()
      .from('historias')
      .update(payload)
      .eq('id', id)
      .select(SELECT)
      .single();
    if (error) throw error;
    return this.mapRow(data as Record<string, unknown>);
  }

  async delete(id: string): Promise<void> {
    const { error } = await getSupabase().from('historias').delete().eq('id', id);
    if (error) throw error;
  }

  async fetchRecentComments(limit = 80): Promise<HistoriaCommentRow[]> {
    const { data, error } = await getSupabase()
      .from('historia_comments')
      .select(
        'id, historia_id, user_id, body, created_at, profiles!user_id (handle, display_name), historias!historia_id (title, kind)',
      )
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapComment(row as Record<string, unknown>));
  }

  async deleteComment(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('historia_comments')
      .delete()
      .eq('id', id);
    if (error) throw error;
  }

  async uploadCover(historiaId: string, file: File): Promise<string> {
    return this.uploadImage(historiaId, file, `${historiaId}.`);
  }

  async uploadPageImage(historiaId: string, file: File): Promise<string> {
    return this.uploadImage(historiaId, file, `${historiaId}/p${Date.now()}.`);
  }

  private async uploadImage(
    historiaId: string,
    file: File,
    namePrefix: string,
  ): Promise<string> {
    if (file.size > 3 * 1024 * 1024) {
      throw new Error('La imagen no puede superar 3 MB.');
    }
    const userId = await this.requireUserId();
    const ext = this.extension(file);
    const path = `${userId}/${namePrefix}${ext}`;
    const { error } = await getSupabase().storage
      .from('historia-covers')
      .upload(path, file, { upsert: true, contentType: file.type || 'image/jpeg' });
    if (error) throw error;
    const { data } = getSupabase().storage.from('historia-covers').getPublicUrl(path);
    return `${data.publicUrl}?v=${Date.now()}`;
  }

  kindLabel(kind: HistoriaKind): string {
    return HISTORIA_KIND_OPTIONS.find((item) => item.id === kind)?.label ?? 'Artículo';
  }

  kindBlurb(kind: HistoriaKind): string {
    return (
      HISTORIA_KIND_OPTIONS.find((item) => item.id === kind)?.blurb ??
      HISTORIA_KIND_OPTIONS[1].blurb
    );
  }

  publishLabel(kind: HistoriaKind): string {
    return `Publicar ${this.kindLabel(kind).toLowerCase()}`;
  }

  statusLabel(status: HistoriaStatus): string {
    switch (status) {
      case 'draft':
        return 'Borrador';
      case 'hidden':
        return 'Oculta';
      case 'scheduled':
        return 'Programada';
      case 'pending_review':
        return 'En revisión';
      default:
        return 'Publicada';
    }
  }

  private mapRow(row: Record<string, unknown>): HistoriaRow {
    const kindRaw = String(row['kind'] ?? 'articulo');
    const kind = KIND_SET.has(kindRaw as HistoriaKind)
      ? (kindRaw as HistoriaKind)
      : 'articulo';
    const statusRaw = String(row['status'] ?? 'published');
    const status: HistoriaStatus =
      statusRaw === 'draft' ||
      statusRaw === 'hidden' ||
      statusRaw === 'scheduled' ||
      statusRaw === 'pending_review'
        ? statusRaw
        : 'published';
    const profileRaw = row['profiles'];
    const profile =
      profileRaw && typeof profileRaw === 'object'
        ? (profileRaw as Record<string, unknown>)
        : null;
    return {
      id: String(row['id']),
      authorId: String(row['author_id']),
      title: String(row['title'] ?? ''),
      excerpt: String(row['excerpt'] ?? ''),
      kind,
      coverImageUrl: (row['cover_image_url'] as string | null) ?? null,
      pages: this.parsePages(row['pages']),
      status,
      scheduledAt:
        typeof row['scheduled_at'] === 'string' ? row['scheduled_at'] : null,
      reviewNote:
        typeof row['review_note'] === 'string' ? row['review_note'] : null,
      commentCount: Number(row['comment_count'] ?? 0),
      createdAt: String(row['created_at'] ?? ''),
      updatedAt: String(row['updated_at'] ?? row['created_at'] ?? ''),
      authorHandle:
        typeof profile?.['handle'] === 'string' ? profile['handle'] : undefined,
      authorDisplayName:
        typeof profile?.['display_name'] === 'string'
          ? profile['display_name']
          : undefined,
    };
  }

  private mapComment(row: Record<string, unknown>): HistoriaCommentRow {
    const profileRaw = row['profiles'];
    const profile =
      profileRaw && typeof profileRaw === 'object'
        ? (profileRaw as Record<string, unknown>)
        : null;
    const historiaRaw = row['historias'];
    const historia =
      historiaRaw && typeof historiaRaw === 'object'
        ? (historiaRaw as Record<string, unknown>)
        : null;
    const handle =
      typeof profile?.['handle'] === 'string' ? profile['handle'] : '';
    return {
      id: String(row['id']),
      historiaId: String(row['historia_id'] ?? ''),
      historiaTitle:
        typeof historia?.['title'] === 'string' ? historia['title'] : 'Obra',
      userId: String(row['user_id'] ?? ''),
      userHandle: handle,
      userDisplayName:
        typeof profile?.['display_name'] === 'string'
          ? profile['display_name']
          : handle || 'Cofrade',
      body: String(row['body'] ?? ''),
      createdAt: String(row['created_at'] ?? ''),
    };
  }

  parsePages(raw: unknown): HistoriaPage[] {
    if (!Array.isArray(raw)) return [];
    return raw
      .map((item) => {
        if (typeof item === 'string') return { body: item };
        if (item && typeof item === 'object') {
          const row = item as Record<string, unknown>;
          return {
            body: String(row['body'] ?? row['text'] ?? ''),
            image_url:
              typeof row['image_url'] === 'string' ? row['image_url'] : undefined,
            caption: typeof row['caption'] === 'string' ? row['caption'] : undefined,
          };
        }
        return { body: String(item ?? '') };
      })
      .filter((page) => page.body.trim() || page.image_url);
  }

  private extension(file: File): string {
    const name = file.name.toLowerCase();
    if (name.endsWith('.png') || file.type === 'image/png') return 'png';
    if (name.endsWith('.webp') || file.type === 'image/webp') return 'webp';
    return 'jpg';
  }

  private async requireUserId(): Promise<string> {
    const { data } = await getSupabase().auth.getUser();
    const id = data.user?.id;
    if (!id) throw new Error('Sesión no válida');
    return id;
  }
}
