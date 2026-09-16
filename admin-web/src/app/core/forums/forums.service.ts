import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';

export const FORUMS_LIST_HERO_KEY = 'forums_list_hero_image_url';

export const PINNED_PARENT_FORUM_IDS = [
  'foro-cofradiero',
  'pentagrama-cofrade',
  'martillo-trabajadera',
] as const;

export type PinnedParentForumId = (typeof PINNED_PARENT_FORUM_IDS)[number];

/** Foros que no se pueden borrar desde admin (núcleo de la app). */
export const PROTECTED_FORUM_PILLAR_IDS = new Set<string>([
  ...PINNED_PARENT_FORUM_IDS,
  'hermandades',
  'noticias',
]);

export const SEASON_KEYS = [
  { value: 'cuaresma', label: 'Cuaresma' },
  { value: 'semana_santa', label: 'Semana Santa' },
  { value: 'glorias', label: 'Glorias' },
] as const;

export const FORUM_ICON_KEYS = [
  { value: 'church', label: 'Iglesia' },
  { value: 'music_note', label: 'Música' },
  { value: 'workspace_premium_outlined', label: 'Destacado' },
  { value: 'groups_outlined', label: 'Grupos' },
  { value: 'account_balance', label: 'Templo / SS' },
  { value: 'filter_vintage_outlined', label: 'Cuaresma' },
  { value: 'wb_sunny_outlined', label: 'Glorias' },
  { value: 'newspaper_outlined', label: 'Noticias' },
  { value: 'face_3', label: 'Persona' },
  { value: 'wine_bar_outlined', label: 'Copa' },
  { value: 'map_outlined', label: 'Mapa' },
] as const;

export interface ForumPillar {
  id: string;
  name: string;
  description: string;
  sortOrder: number;
  isEnabled: boolean;
  isActive: boolean;
  lockedLabel: string | null;
  coverImageUrl: string | null;
  iconImageUrl: string | null;
  aboutTagline: string | null;
  aboutBody: string | null;
  forumRules: string | null;
  topicCount: number;
  messageCount: number;
}

export interface PinnedSystemTopic {
  id: string;
  forumId: string;
  title: string;
  excerpt: string;
  body: string;
  pinSortOrder: number;
  isListed: boolean;
  seasonKey: string | null;
  iconKey: string | null;
  coverImageUrl: string | null;
  showHubTitle: boolean;
}

@Injectable({ providedIn: 'root' })
export class ForumsService {
  async fetchPillars(): Promise<ForumPillar[]> {
    const { data, error } = await getSupabase()
      .from('forum_pillars')
      .select(
        'id, name, description, sort_order, is_enabled, is_active, locked_label, cover_image_url, icon_image_url, about_tagline, about_body, forum_rules, topic_count, message_count',
      )
      .order('sort_order', { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapPillar(row as Record<string, unknown>));
  }

  async updatePillar(input: {
    id: string;
    name?: string;
    description?: string;
    isEnabled?: boolean;
    isActive?: boolean;
    coverImageUrl?: string | null;
    aboutTagline?: string | null;
    aboutBody?: string | null;
    forumRules?: string | null;
  }): Promise<void> {
    const patch: Record<string, unknown> = {};
    if (input.name != null) patch['name'] = input.name.trim();
    if (input.description != null) patch['description'] = input.description.trim();
    if (input.isEnabled != null) patch['is_enabled'] = input.isEnabled;
    if (input.isActive != null) patch['is_active'] = input.isActive;
    if (input.coverImageUrl !== undefined) {
      const v = input.coverImageUrl?.trim() ?? '';
      patch['cover_image_url'] = v || null;
    }
    if (input.aboutTagline !== undefined) {
      const v = input.aboutTagline?.trim() ?? '';
      patch['about_tagline'] = v || null;
    }
    if (input.aboutBody !== undefined) {
      const v = input.aboutBody?.trim() ?? '';
      patch['about_body'] = v || null;
    }
    if (input.forumRules !== undefined) {
      const v = input.forumRules?.trim() ?? '';
      patch['forum_rules'] = v || null;
    }
    if (!Object.keys(patch).length) return;

    const { error } = await getSupabase()
      .from('forum_pillars')
      .update(patch)
      .eq('id', input.id);
    if (error) throw error;
  }

  canDeletePillar(pillarId: string): boolean {
    return !PROTECTED_FORUM_PILLAR_IDS.has(pillarId);
  }

  async deletePillar(pillarId: string): Promise<void> {
    if (!this.canDeletePillar(pillarId)) {
      throw new Error('Este foro es del núcleo de la app y no se puede eliminar.');
    }
    const { error } = await getSupabase()
      .from('forum_pillars')
      .delete()
      .eq('id', pillarId);
    if (error) throw error;
  }

  async fetchForumsListHeroUrl(): Promise<string | null> {
    const { data, error } = await getSupabase()
      .from('app_config')
      .select('value')
      .eq('key', FORUMS_LIST_HERO_KEY)
      .maybeSingle();
    if (error) throw error;
    const value = String(data?.['value'] ?? '').trim();
    return value || null;
  }

  async setForumsListHeroUrl(url: string): Promise<void> {
    const { error } = await getSupabase().from('app_config').upsert({
      key: FORUMS_LIST_HERO_KEY,
      value: url.trim(),
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
  }

  async uploadForumsListHero(file: File): Promise<string> {
    this.assertImage(file, 5 * 1024 * 1024);
    const ext = this.extFromFile(file);
    const path = `_global/forums-hero.${ext}`;
    const { error } = await getSupabase().storage.from('forum-covers').upload(path, file, {
      upsert: true,
      contentType: file.type || `image/${ext}`,
    });
    if (error) throw error;
    return this.publicUrl('forum-covers', path);
  }

  async uploadPillarCover(pillarId: string, file: File): Promise<string> {
    this.assertImage(file, 5 * 1024 * 1024);
    const ext = this.extFromFile(file);
    const path = `${pillarId}/cover.${ext}`;
    const { error } = await getSupabase().storage.from('forum-covers').upload(path, file, {
      upsert: true,
      contentType: file.type || `image/${ext}`,
    });
    if (error) throw error;
    return this.publicUrl('forum-covers', path);
  }

  async fetchPinnedSystemTopics(): Promise<PinnedSystemTopic[]> {
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select(
        'id, forum_id, title, excerpt, body, pin_sort_order, is_listed, season_key, icon_key, cover_image_url, show_hub_title',
      )
      .eq('is_system', true)
      .eq('is_pinned', true)
      .order('pin_sort_order', { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapPinned(row as Record<string, unknown>));
  }

  async createPinnedSystemTopic(input: {
    forumId: string;
    title: string;
    excerpt?: string;
    body?: string;
    seasonKey?: string | null;
    iconKey?: string;
  }): Promise<void> {
    const title = input.title.trim();
    if (title.length < 2) throw new Error('El título debe tener al menos 2 caracteres.');
    if (!PINNED_PARENT_FORUM_IDS.includes(input.forumId as PinnedParentForumId)) {
      throw new Error('Ese foro no admite temas destacados de sistema.');
    }

    const existing = await this.fetchPinnedSystemTopics();
    const inForum = existing.filter((t) => t.forumId === input.forumId);
    const nextOrder = inForum.length
      ? Math.max(...inForum.map((t) => t.pinSortOrder)) + 1
      : 1;

    const excerpt =
      input.excerpt?.trim() || `Espacio de conversación sobre ${title}.`;
    const body =
      input.body?.trim() ||
      `Espacio destacado para ${title}.\n\nComparte noticias y conversación con la comunidad.`;

    const { error } = await getSupabase().from('forum_topics').insert({
      id: this.pinnedTopicId(input.forumId, title),
      forum_id: input.forumId,
      author_handle: '@cofradeo',
      title,
      excerpt,
      body,
      status: 'published',
      is_pinned: true,
      is_system: true,
      pin_sort_order: nextOrder,
      is_listed: true,
      icon_key: input.iconKey || 'church',
      season_key:
        input.forumId === 'foro-cofradiero' && input.seasonKey
          ? input.seasonKey
          : null,
    });
    if (error) throw error;
  }

  async updatePinnedTopicSettings(input: {
    id: string;
    excerpt?: string;
    body?: string;
    iconKey?: string | null;
    coverImageUrl?: string | null;
    pinSortOrder?: number;
    isListed?: boolean;
    showHubTitle?: boolean;
  }): Promise<void> {
    const patch: Record<string, unknown> = {};
    if (input.excerpt != null) patch['excerpt'] = input.excerpt.trim();
    if (input.body != null) patch['body'] = input.body.trim();
    if (input.iconKey !== undefined) {
      const v = input.iconKey?.trim() ?? '';
      patch['icon_key'] = v || null;
    }
    if (input.coverImageUrl !== undefined) {
      const v = input.coverImageUrl?.trim() ?? '';
      patch['cover_image_url'] = v || null;
    }
    if (input.pinSortOrder != null) patch['pin_sort_order'] = input.pinSortOrder;
    if (input.isListed != null) patch['is_listed'] = input.isListed;
    if (input.showHubTitle != null) patch['show_hub_title'] = input.showHubTitle;
    if (!Object.keys(patch).length) return;

    const { error } = await getSupabase()
      .from('forum_topics')
      .update(patch)
      .eq('id', input.id);
    if (error) throw error;
  }

  async deletePinnedSystemTopic(topicId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('forum_topics')
      .delete()
      .eq('id', topicId)
      .eq('is_system', true);
    if (error) throw error;
  }

  async uploadTopicCover(topicId: string, file: File): Promise<string> {
    this.assertImage(file, 3 * 1024 * 1024);
    const path = `${topicId}/cover.jpg`;
    const { error } = await getSupabase().storage.from('topic-covers').upload(path, file, {
      upsert: true,
      contentType: file.type || 'image/jpeg',
    });
    if (error) throw error;
    return this.publicUrl('topic-covers', path);
  }

  async swapPinnedOrder(a: PinnedSystemTopic, b: PinnedSystemTopic): Promise<void> {
    await this.updatePinnedTopicSettings({ id: a.id, pinSortOrder: b.pinSortOrder });
    await this.updatePinnedTopicSettings({ id: b.id, pinSortOrder: a.pinSortOrder });
  }

  parentForumLabel(forumId: string): string {
    switch (forumId) {
      case 'foro-cofradiero':
        return 'Círculo Cofrade';
      case 'pentagrama-cofrade':
        return 'Pentagrama Cofrade';
      case 'martillo-trabajadera':
        return 'Martillo y Trabajadera';
      default:
        return forumId;
    }
  }

  seasonLabel(key: string | null): string {
    if (!key) return '';
    return SEASON_KEYS.find((s) => s.value === key)?.label ?? key;
  }

  private pinnedTopicId(forumId: string, title: string): string {
    const prefix =
      forumId === 'foro-cofradiero'
        ? 'circulo'
        : forumId === 'martillo-trabajadera'
          ? 'martillo'
          : forumId === 'pentagrama-cofrade'
            ? 'pentagrama'
            : forumId.split('-')[0] || 'tema';
    const slug = title
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/ñ/g, 'n')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
    return `${prefix}-${slug || 'tema'}`;
  }

  private assertImage(file: File, maxBytes: number): void {
    if (file.size > maxBytes) {
      throw new Error(`La imagen no puede superar ${Math.round(maxBytes / (1024 * 1024))} MB.`);
    }
    const ok = ['image/png', 'image/jpeg', 'image/webp'].includes(file.type);
    if (file.type && !ok) {
      throw new Error('Usa PNG, JPEG o WebP.');
    }
  }

  private extFromFile(file: File): string {
    const fromName = (file.name.split('.').pop() || '').toLowerCase();
    if (fromName === 'png' || fromName === 'webp' || fromName === 'jpg' || fromName === 'jpeg') {
      return fromName === 'jpeg' ? 'jpg' : fromName;
    }
    if (file.type.includes('png')) return 'png';
    if (file.type.includes('webp')) return 'webp';
    return 'jpg';
  }

  private publicUrl(bucket: string, path: string): string {
    const base = getSupabase().storage.from(bucket).getPublicUrl(path).data.publicUrl;
    return `${base}?v=${Date.now()}`;
  }

  private mapPillar(row: Record<string, unknown>): ForumPillar {
    return {
      id: String(row['id'] ?? ''),
      name: String(row['name'] ?? ''),
      description: String(row['description'] ?? ''),
      sortOrder: Number(row['sort_order'] ?? 0),
      isEnabled: Boolean(row['is_enabled'] ?? true),
      isActive: Boolean(row['is_active'] ?? false),
      lockedLabel: (row['locked_label'] as string | null) ?? null,
      coverImageUrl: (row['cover_image_url'] as string | null) ?? null,
      iconImageUrl: (row['icon_image_url'] as string | null) ?? null,
      aboutTagline: (row['about_tagline'] as string | null) ?? null,
      aboutBody: (row['about_body'] as string | null) ?? null,
      forumRules: (row['forum_rules'] as string | null) ?? null,
      topicCount: Number(row['topic_count'] ?? 0),
      messageCount: Number(row['message_count'] ?? 0),
    };
  }

  private mapPinned(row: Record<string, unknown>): PinnedSystemTopic {
    return {
      id: String(row['id'] ?? ''),
      forumId: String(row['forum_id'] ?? ''),
      title: String(row['title'] ?? ''),
      excerpt: String(row['excerpt'] ?? ''),
      body: String(row['body'] ?? ''),
      pinSortOrder: Number(row['pin_sort_order'] ?? 0),
      isListed: Boolean(row['is_listed'] ?? true),
      seasonKey: (row['season_key'] as string | null) ?? null,
      iconKey: (row['icon_key'] as string | null) ?? null,
      coverImageUrl: (row['cover_image_url'] as string | null) ?? null,
      showHubTitle: row['show_hub_title'] !== false,
    };
  }
}
