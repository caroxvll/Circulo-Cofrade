import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';
import { parseHermandadTopicTitle } from '../community/community.service';
import type { CalendarEventType } from '../events/events.models';

/** Categoría en tablón (BD / app). */
export const OFFICIAL_CATEGORIES = [
  { value: 'noticia', label: 'Noticia' },
  { value: 'culto', label: 'Culto' },
  { value: 'acto', label: 'Acto' },
  { value: 'patrimonio', label: 'Patrimonio' },
] as const;

export type OfficialCategory = (typeof OFFICIAL_CATEGORIES)[number]['value'];

/**
 * Tipo que elige la hermandad al publicar.
 * Controla destinos (tablón / calendario / noticias) sin etiquetas sueltas.
 */
export interface PublishKind {
  id: string;
  label: string;
  hint: string;
  /** Sección del tablón en la app. */
  officialCategory: OfficialCategory;
  /** Siempre en tablón. */
  boardDefault: true;
  calendarDefault: boolean;
  calendarType: CalendarEventType | null;
  /** Portada Noticias: casi nunca. */
  noticiasDefault: boolean;
  needsDate: boolean;
}

export const PUBLISH_KINDS: readonly PublishKind[] = [
  {
    id: 'noticia',
    label: 'Nota / comunicado',
    hint: 'Solo en tu tablón. No satura Noticias ni el calendario.',
    officialCategory: 'noticia',
    boardDefault: true,
    calendarDefault: false,
    calendarType: null,
    noticiasDefault: false,
    needsDate: false,
  },
  {
    id: 'culto',
    label: 'Culto / misa',
    hint: 'Tablón + calendario. No va a Noticias.',
    officialCategory: 'culto',
    boardDefault: true,
    calendarDefault: true,
    calendarType: 'evento',
    noticiasDefault: false,
    needsDate: true,
  },
  {
    id: 'ensayo',
    label: 'Ensayo',
    hint: 'Tablón + calendario (ensayos).',
    officialCategory: 'acto',
    boardDefault: true,
    calendarDefault: true,
    calendarType: 'ensayo',
    noticiasDefault: false,
    needsDate: true,
  },
  {
    id: 'iguala',
    label: 'Iguala de costaleros',
    hint: 'Tablón + calendario (igualás).',
    officialCategory: 'acto',
    boardDefault: true,
    calendarDefault: true,
    calendarType: 'iguala',
    noticiasDefault: false,
    needsDate: true,
  },
  {
    id: 'procesion',
    label: 'Procesión / salida',
    hint: 'Tablón + calendario. Noticias solo si lo marcas (poco habitual).',
    officialCategory: 'acto',
    boardDefault: true,
    calendarDefault: true,
    calendarType: 'procesion',
    noticiasDefault: false,
    needsDate: true,
  },
  {
    id: 'acto',
    label: 'Acto / evento',
    hint: 'Tablón + calendario genérico.',
    officialCategory: 'acto',
    boardDefault: true,
    calendarDefault: true,
    calendarType: 'evento',
    noticiasDefault: false,
    needsDate: true,
  },
  {
    id: 'concierto',
    label: 'Concierto',
    hint: 'Tablón + calendario (conciertos).',
    officialCategory: 'acto',
    boardDefault: true,
    calendarDefault: true,
    calendarType: 'concierto',
    noticiasDefault: false,
    needsDate: true,
  },
  {
    id: 'patrimonio',
    label: 'Patrimonio',
    hint: 'Solo tablón (restauración, enseres…).',
    officialCategory: 'patrimonio',
    boardDefault: true,
    calendarDefault: false,
    calendarType: null,
    noticiasDefault: false,
    needsDate: false,
  },
] as const;

export type PublishKindId = (typeof PUBLISH_KINDS)[number]['id'];

export function publishKindById(id: string): PublishKind {
  return PUBLISH_KINDS.find((k) => k.id === id) ?? PUBLISH_KINDS[0];
}

export interface HermandadBoard {
  topicId: string;
  title: string;
  processionDay: string | null;
  hermandadName: string;
  excerpt: string;
}

export interface HermandadOfficialPost {
  id: string;
  topicId: string;
  body: string;
  category: OfficialCategory;
  imageUrl: string | null;
  createdAt: string;
  deletedAt: string | null;
}

export interface PublishDestinations {
  board: boolean;
  calendar: boolean;
  /** Reservado: aún no crea noticia de ciudad (evitar desborde). */
  noticias: boolean;
}

@Injectable({ providedIn: 'root' })
export class HermandadPortalService {
  async fetchAssignedBoards(profileId: string): Promise<HermandadBoard[]> {
    const { data, error } = await getSupabase()
      .from('hermandad_topic_accounts')
      .select('topic_id, forum_topics(id, title, excerpt)')
      .eq('profile_id', profileId);
    if (error) throw error;

    return (data ?? []).map((row) => {
      const topic = row.forum_topics as {
        id?: string;
        title?: string;
        excerpt?: string;
      } | null;
      const title = String(topic?.title ?? row.topic_id);
      const parsed = parseHermandadTopicTitle(title);
      return {
        topicId: String(topic?.id ?? row.topic_id),
        title,
        processionDay: parsed.processionDay,
        hermandadName: parsed.hermandadName,
        excerpt: String(topic?.excerpt ?? ''),
      };
    });
  }

  async fetchOfficialPosts(
    profileId: string,
    topicIds: string[],
  ): Promise<HermandadOfficialPost[]> {
    if (!topicIds.length) return [];
    const { data, error } = await getSupabase()
      .from('forum_replies')
      .select(
        'id, topic_id, content, official_category, image_url, created_at, deleted_at',
      )
      .eq('author_id', profileId)
      .eq('is_official', true)
      .in('topic_id', topicIds)
      .order('created_at', { ascending: false })
      .limit(80);
    if (error) throw error;

    return (data ?? []).map((row) => ({
      id: String(row.id),
      topicId: String(row.topic_id),
      body: String(row.content ?? ''),
      category: (row.official_category as OfficialCategory) || 'noticia',
      imageUrl: (row.image_url as string | null) ?? null,
      createdAt: String(row.created_at ?? ''),
      deletedAt: (row.deleted_at as string | null) ?? null,
    }));
  }

  async uploadPostImage(topicId: string, file: File): Promise<string> {
    const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg';
    const safeExt = ['png', 'webp', 'jpeg', 'jpg'].includes(ext) ? ext : 'jpg';
    const path = `${topicId}/${crypto.randomUUID()}.${safeExt}`;
    const { error } = await getSupabase()
      .storage.from('forum-post-images')
      .upload(path, file, {
        upsert: false,
        contentType: file.type || 'image/jpeg',
      });
    if (error) throw error;
    return getSupabase().storage.from('forum-post-images').getPublicUrl(path)
      .data.publicUrl;
  }

  async createOfficialPost(input: {
    topicId: string;
    authorId: string;
    authorHandle: string;
    body: string;
    category: OfficialCategory;
    imageUrl?: string | null;
  }): Promise<string> {
    const content = input.body.trim();
    if (content.length < 3) {
      throw new Error('Escribe al menos unas líneas de contenido.');
    }

    const { data, error } = await getSupabase()
      .from('forum_replies')
      .insert({
        topic_id: input.topicId,
        author_id: input.authorId,
        author_handle: input.authorHandle.startsWith('@')
          ? input.authorHandle
          : `@${input.authorHandle}`,
        content,
        is_official: true,
        official_category: input.category,
        image_url: input.imageUrl?.trim() || null,
      })
      .select('id')
      .single();
    if (error) throw error;
    return String(data.id);
  }

  async createCalendarEventFromPost(input: {
    title: string;
    subtitle: string;
    eventType: CalendarEventType;
    startsAtIso: string;
    location?: string | null;
    organizerLabel: string;
    coverImageUrl?: string | null;
    createdBy: string;
  }): Promise<void> {
    const { error } = await getSupabase().from('calendar_events').insert({
      title: input.title.trim(),
      subtitle: input.subtitle.trim(),
      event_type: input.eventType,
      starts_at: input.startsAtIso,
      location: input.location?.trim() || null,
      organizer_label: input.organizerLabel.trim(),
      cover_image_url: input.coverImageUrl?.trim() || null,
      created_by: input.createdBy,
      status: 'published',
    });
    if (error) throw error;
  }

  categoryLabel(value: string): string {
    return OFFICIAL_CATEGORIES.find((c) => c.value === value)?.label ?? value;
  }
}
