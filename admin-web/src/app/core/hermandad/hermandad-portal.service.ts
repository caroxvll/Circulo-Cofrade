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
    hint: 'Solo en tu tablón.',
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
    hint: 'Tablón y, si quieres, calendario.',
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
    hint: 'Tablón y, si quieres, calendario.',
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
    hint: 'Tablón y, si quieres, calendario.',
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
    hint: 'Tablón y, si quieres, calendario.',
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
    hint: 'Tablón y, si quieres, calendario.',
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
    hint: 'Tablón y, si quieres, calendario.',
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
    hint: 'Solo en tu tablón.',
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
  coverImageUrl: string | null;
  iconImageUrl: string | null;
  viewCount: number;
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

export interface TopicFollowerRow {
  followerId: string;
  handle: string;
  displayName: string;
  avatarUrl: string | null;
  followedAt: string;
}

export interface HermandadScheduledPost {
  id: string;
  topicId: string;
  body: string;
  category: OfficialCategory;
  imageUrl: string | null;
  scheduledAt: string;
  status: 'draft' | 'scheduled' | 'published' | 'cancelled';
  updatedAt: string;
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
      .select(
        'topic_id, forum_topics(id, title, excerpt, cover_image_url, icon_image_url, view_count)',
      )
      .eq('profile_id', profileId);
    if (error) throw error;

    return (data ?? []).map((row) => {
      const topic = row.forum_topics as {
        id?: string;
        title?: string;
        excerpt?: string;
        cover_image_url?: string | null;
        icon_image_url?: string | null;
        view_count?: number | null;
      } | null;
      const title = String(topic?.title ?? row.topic_id);
      const parsed = parseHermandadTopicTitle(title);
      return {
        topicId: String(topic?.id ?? row.topic_id),
        title,
        processionDay: parsed.processionDay,
        hermandadName: parsed.hermandadName,
        excerpt: String(topic?.excerpt ?? ''),
        coverImageUrl: (topic?.cover_image_url as string | null) ?? null,
        iconImageUrl: (topic?.icon_image_url as string | null) ?? null,
        viewCount: Number(topic?.view_count ?? 0),
      };
    });
  }

  async countTopicFollowers(topicId: string): Promise<number> {
    // RLS en follows solo deja ver filas propias; el RPC cuenta el total real.
    const { data, error } = await getSupabase().rpc('count_topic_followers', {
      p_topic_id: topicId,
    });
    if (error) throw error;
    return Number(data ?? 0);
  }

  async fetchTopicFollowers(
    topicId: string,
    limit = 50,
    offset = 0,
  ): Promise<TopicFollowerRow[]> {
    const { data, error } = await getSupabase().rpc(
      'list_topic_followers_for_organizer',
      {
        p_topic_id: topicId,
        p_limit: limit,
        p_offset: offset,
      },
    );
    if (error) throw error;
    return (data ?? []).map(
      (row: {
        follower_id?: string;
        handle?: string;
        display_name?: string;
        avatar_url?: string | null;
        followed_at?: string;
      }) => ({
        followerId: String(row.follower_id ?? ''),
        handle: String(row.handle ?? ''),
        displayName: String(row.display_name ?? ''),
        avatarUrl: (row.avatar_url as string | null) ?? null,
        followedAt: String(row.followed_at ?? ''),
      }),
    );
  }

  async fetchUpcomingOwnEvents(
    profileId: string,
    limit = 30,
  ): Promise<
    Array<{
      id: string;
      title: string;
      startsAt: string;
      location: string | null;
      coverImageUrl: string | null;
      eventType: string;
    }>
  > {
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .select(
        'id, title, starts_at, location, cover_image_url, event_type, status',
      )
      .eq('created_by', profileId)
      .eq('status', 'published')
      .gte('starts_at', new Date().toISOString())
      .order('starts_at', { ascending: true })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: String(row.id),
      title: String(row.title ?? ''),
      startsAt: String(row.starts_at ?? ''),
      location: (row.location as string | null) ?? null,
      coverImageUrl: (row.cover_image_url as string | null) ?? null,
      eventType: String(row.event_type ?? 'evento'),
    }));
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
    /** Escudo del tablón de la hermandad (icon_image_url). */
    customIconUrl?: string | null;
    createdBy: string;
    /** Comunicado oficial que originó el evento (si hay). */
    sourceReplyId?: string | null;
  }): Promise<void> {
    const organizerLabel = input.organizerLabel.trim();
    const customIconUrl = input.customIconUrl?.trim() || '';
    const coverImageUrl = input.coverImageUrl?.trim() || '';

    const { error } = await getSupabase().from('calendar_events').insert({
      title: input.title.trim(),
      subtitle: input.subtitle.trim(),
      event_type: input.eventType,
      starts_at: input.startsAtIso,
      location: input.location?.trim() || null,
      organizer_label: organizerLabel,
      cover_image_url: coverImageUrl,
      custom_icon_url: customIconUrl,
      created_by: input.createdBy,
      status: 'published',
      source_reply_id: input.sourceReplyId?.trim() || null,
    });
    if (error) throw error;

    // Guarda el escudo en biblioteca para reutilizarlo en próximos eventos.
    if (organizerLabel.length >= 3 && customIconUrl) {
      const organizerKey = organizerLabel
        .toLowerCase()
        .trim()
        .replace(/\s+/g, ' ')
        .replace(/\.+/g, '.');
      const { error: logoError } = await getSupabase()
        .from('organizer_logos')
        .upsert(
          {
            organizer_key: organizerKey,
            display_label: organizerLabel,
            logo_url: customIconUrl,
            updated_by: input.createdBy,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'organizer_key' },
        );
      if (logoError) {
        console.warn(
          'Evento creado, pero no se pudo guardar el escudo en biblioteca',
          logoError,
        );
      }
    }
  }

  async updateOfficialPost(input: {
    replyId: string;
    body: string;
    category: OfficialCategory;
    imageUrl?: string | null;
    clearImage?: boolean;
  }): Promise<void> {
    const content = input.body.trim();
    if (content.length < 1 && !input.clearImage) {
      throw new Error('El contenido no puede quedar vacío.');
    }
    const { error } = await getSupabase().rpc('update_official_hermandad_post', {
      p_reply_id: input.replyId,
      p_content: content,
      p_official_category: input.category,
      p_image_url: input.imageUrl ?? null,
      p_clear_image: input.clearImage ?? false,
    });
    if (error) throw error;
  }

  async softDeleteOfficialPost(replyId: string): Promise<void> {
    const client = getSupabase();

    // Antes: título para limpiar eventos huérfanos sin source_reply_id (legado).
    const { data: replyRow } = await client
      .from('forum_replies')
      .select('content, author_id')
      .eq('id', replyId)
      .maybeSingle();

    const { error } = await client.rpc('soft_delete_forum_reply', {
      p_reply_id: replyId,
    });
    if (error) throw error;

    // soft_delete_forum_reply ya borra eventos con source_reply_id + notifs.
    // Legado: eventos creados sin enlace.
    const authorId = (replyRow?.author_id as string | undefined)?.trim();
    const title = this.extractPostTitle((replyRow?.content as string) ?? '');
    if (authorId && title.length >= 3) {
      const { error: orphanErr } = await client
        .from('calendar_events')
        .delete()
        .eq('created_by', authorId)
        .eq('title', title)
        .is('source_reply_id', null)
        .eq('status', 'published');
      if (orphanErr) {
        console.warn('No se pudieron borrar eventos huérfanos del post', orphanErr);
      }
    }
  }

  /** Título del comunicado (`**titulo**` al inicio) o primeras palabras. */
  extractPostTitle(content: string): string {
    const trimmed = content.trim();
    const bold = trimmed.match(/^\*\*(.+?)\*\*/);
    if (bold?.[1]) return bold[1].trim();
    const firstLine = trimmed.split(/\n/)[0]?.trim() ?? '';
    return firstLine.slice(0, 120);
  }

  async deleteOwnCalendarEvent(eventId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('calendar_events')
      .delete()
      .eq('id', eventId);
    if (error) throw error;
  }

  async createScheduledPost(input: {
    topicId: string;
    authorId: string;
    authorHandle: string;
    body: string;
    category: OfficialCategory;
    scheduledAtIso: string;
    imageUrl?: string | null;
    calendar?: {
      eventType: CalendarEventType;
      startsAtIso: string;
      location?: string | null;
      title?: string | null;
      coverImageUrl?: string | null;
      customIconUrl?: string | null;
      organizerLabel?: string | null;
    } | null;
  }): Promise<string> {
    const content = input.body.trim();
    if (content.length < 3) {
      throw new Error('Escribe al menos unas líneas de contenido.');
    }
    const when = new Date(input.scheduledAtIso);
    const min = Date.now() + 5 * 60 * 1000;
    if (Number.isNaN(when.getTime()) || when.getTime() <= min) {
      throw new Error(
        'La fecha programada debe ser al menos 5 minutos en el futuro.',
      );
    }

    const cal = input.calendar ?? null;
    const { data, error } = await getSupabase()
      .from('hermandad_scheduled_posts')
      .insert({
        topic_id: input.topicId,
        author_id: input.authorId,
        author_handle: input.authorHandle.startsWith('@')
          ? input.authorHandle
          : `@${input.authorHandle}`,
        content,
        official_category: input.category,
        scheduled_at: when.toISOString(),
        status: 'scheduled',
        image_url: input.imageUrl?.trim() || null,
        calendar_event_type: cal?.eventType ?? null,
        calendar_starts_at: cal?.startsAtIso ?? null,
        calendar_location: cal?.location?.trim() || null,
        calendar_title: cal?.title?.trim() || null,
        calendar_cover_image_url: cal?.coverImageUrl?.trim() || null,
        calendar_custom_icon_url: cal?.customIconUrl?.trim() || null,
        calendar_organizer_label: cal?.organizerLabel?.trim() || null,
      })
      .select('id')
      .single();
    if (error) throw error;
    return String(data.id);
  }

  async fetchScheduledPosts(
    profileId: string,
    topicIds: string[],
  ): Promise<HermandadScheduledPost[]> {
    if (!topicIds.length) return [];
    const { data, error } = await getSupabase()
      .from('hermandad_scheduled_posts')
      .select(
        'id, topic_id, content, official_category, image_url, scheduled_at, status, updated_at',
      )
      .eq('author_id', profileId)
      .eq('status', 'scheduled')
      .in('topic_id', topicIds)
      .order('scheduled_at', { ascending: true })
      .limit(50);
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: String(row.id),
      topicId: String(row.topic_id),
      body: String(row.content ?? ''),
      category: (row.official_category as OfficialCategory) || 'noticia',
      imageUrl: (row.image_url as string | null) ?? null,
      scheduledAt: String(row.scheduled_at ?? ''),
      status: (row.status as HermandadScheduledPost['status']) || 'scheduled',
      updatedAt: String(row.updated_at ?? ''),
    }));
  }

  async cancelScheduledPost(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('hermandad_scheduled_posts')
      .update({
        status: 'cancelled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .eq('status', 'scheduled');
    if (error) throw error;
  }

  categoryLabel(value: string): string {
    return OFFICIAL_CATEGORIES.find((c) => c.value === value)?.label ?? value;
  }
}
