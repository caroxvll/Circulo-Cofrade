import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';

export type HistoriaKind = 'libro' | 'articulo';
export type HistoriaStatus = 'published' | 'hidden' | 'draft' | 'scheduled';

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
  commentCount: number;
  createdAt: string;
  updatedAt: string;
}

const SELECT =
  'id, author_id, title, excerpt, kind, cover_image_url, pages, status, scheduled_at, comment_count, created_at, updated_at';
const LIST_SELECT =
  'id, author_id, title, excerpt, kind, cover_image_url, status, scheduled_at, comment_count, created_at, updated_at';

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
    const { data, error } = await getSupabase()
      .from('historias')
      .update({
        title: input.title.trim(),
        excerpt: input.excerpt.trim(),
        kind: input.kind,
        pages: input.pages,
        status: input.status,
        cover_image_url: input.coverImageUrl ?? null,
        scheduled_at: input.status === 'scheduled' ? input.scheduledAt ?? null : null,
        updated_at: new Date().toISOString(),
      })
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
      statusRaw === 'scheduled'
        ? statusRaw
        : 'published';
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
      commentCount: Number(row['comment_count'] ?? 0),
      createdAt: String(row['created_at'] ?? ''),
      updatedAt: String(row['updated_at'] ?? row['created_at'] ?? ''),
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
