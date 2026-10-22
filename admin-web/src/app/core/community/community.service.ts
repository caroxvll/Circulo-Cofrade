import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';

export interface AdminUserRow {
  id: string;
  handle: string;
  displayName: string;
  role: 'member' | 'admin';
  accountType: 'cofrade' | 'brotherhood' | string;
  verified: boolean;
  suspendedAt: string | null;
  suspendedReason: string | null;
  createdAt: string;
  /** Email de Auth (solo vía admin_list_users). */
  email: string | null;
}

export interface HandleHit {
  id: string;
  handle: string;
  displayName: string;
  avatarUrl: string | null;
  verified: boolean;
}

export interface ForumPillarOption {
  id: string;
  name: string;
}

export interface ModeratorAssignment {
  profileId: string;
  forumId: string;
  handle: string;
  forumName: string;
  assignedAt: string;
}

export interface SsLiveReporterRow {
  profileId: string;
  handle: string;
  assignedAt: string;
  note: string;
}

export interface HermandadTopicOption {
  id: string;
  title: string;
  processionDay: string | null;
  hermandadName: string;
  excerpt: string;
  body: string;
  coverImageUrl: string | null;
  iconImageUrl: string | null;
  createdAt: string;
}

export interface HermandadAssignment {
  profileId: string;
  topicId: string;
  handle: string;
  topicTitle: string;
  createdAt: string;
}

export interface CreatedHermandadAccount {
  profileId: string;
  handle: string;
  displayName: string;
  email: string;
  topicId: string | null;
  temporaryPassword: string | null;
}

export type HermandadAccessRequestStatus =
  | 'pending'
  | 'approved'
  | 'rejected'
  | 'spam';

export type HermandadBoardKind = 'semana_santa' | 'glorias';

export interface HermandadAccessRequest {
  id: string;
  hermandadName: string;
  city: string;
  contactName: string;
  contactEmail: string;
  contactPhone: string;
  message: string;
  /** `semana_santa` (Sevilla) o `glorias`. */
  boardKind: HermandadBoardKind;
  /** Día de estación si es SS; vacío si es Gloria. */
  processionDay: string;
  status: HermandadAccessRequestStatus;
  reviewNotes: string;
  createdProfileId: string | null;
  createdAt: string;
  reviewedAt: string | null;
}

export interface HermandadAccountCredentials {
  profileId: string;
  handle: string;
  displayName: string;
  email: string;
}

/** Categoría de tablones de hermandades de Gloria (no es día de estación). */
export const HERMANDAD_GLORIAS_CATEGORY = 'Glorias';

/** Días de estación SS Sevilla (mismo orden que la app). */
export const HERMANDAD_STATION_DAYS = [
  'Viernes de Dolores',
  'Sábado de Pasión',
  'Domingo de Ramos',
  'Lunes Santo',
  'Martes Santo',
  'Miércoles Santo',
  'Jueves Santo',
  'Madrugá',
  'Viernes Santo',
  'Sábado Santo',
  'Domingo de Resurrección',
] as const;

/** Directorio completo: estación SS + Glorias. */
export const HERMANDAD_DIRECTORY_DAYS = [
  ...HERMANDAD_STATION_DAYS,
  HERMANDAD_GLORIAS_CATEGORY,
] as const;

export function hermandadBoardSeasonKey(
  day: string,
): 'semana_santa' | 'glorias' {
  return day.trim() === HERMANDAD_GLORIAS_CATEGORY
    ? 'glorias'
    : 'semana_santa';
}

export function parseHermandadTopicTitle(title: string): {
  processionDay: string | null;
  hermandadName: string;
} {
  const parts = title
    .split(' · ')
    .map((p) => p.trim())
    .filter(Boolean);
  if (parts.length >= 2) {
    return {
      processionDay: parts[0],
      hermandadName: parts.slice(1).join(' · '),
    };
  }
  return { processionDay: null, hermandadName: title.trim() };
}

export function hermandadBoardTitle(day: string, name: string): string {
  return `${day.trim()} · ${name.trim()}`;
}

export function hermandadBoardTemplate(name: string, day: string): {
  excerpt: string;
  body: string;
} {
  const n = name.trim();
  const d = day.trim();
  const isGloria = d === HERMANDAD_GLORIAS_CATEGORY;
  const scope = isGloria
    ? `de ${n} (hermandad de Gloria)`
    : `de ${n} para el ${d}`;
  return {
    excerpt: `Espacio para noticias, horarios, avisos e información oficial de ${n}.`,
    body:
      `Este es el espacio de seguimiento ${scope}.\n\n` +
      `Aquí se podrán centralizar noticias, horarios, avisos de última hora, ` +
      `comunicados, cambios de itinerario y comentarios de la comunidad.\n\n` +
      `Cuando exista una cuenta verificada de la hermandad, sus publicaciones ` +
      `aparecerán identificadas como información oficial.`,
  };
}

function slugifyHermandadPart(raw: string): string {
  return raw
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40);
}

export function hermandadBoardTopicId(day: string, name: string): string {
  const id = `${slugifyHermandadPart(day)}-${slugifyHermandadPart(name)}`;
  return id || `hermandad-${Date.now()}`;
}

export interface SignupStats {
  today: number;
  last7: number;
  last30: number;
  total: number;
}

@Injectable({ providedIn: 'root' })
export class CommunityService {
  async fetchSignupStats(): Promise<SignupStats> {
    const client = getSupabase();
    const now = new Date();
    const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const start7 = new Date(startToday);
    start7.setDate(start7.getDate() - 6);
    const start30 = new Date(startToday);
    start30.setDate(start30.getDate() - 29);

    const [today, last7, last30, total] = await Promise.all([
      client
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .gte('created_at', startToday.toISOString()),
      client
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .gte('created_at', start7.toISOString()),
      client
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .gte('created_at', start30.toISOString()),
      client.from('profiles').select('id', { count: 'exact', head: true }),
    ]);

    return {
      today: today.count ?? 0,
      last7: last7.count ?? 0,
      last30: last30.count ?? 0,
      total: total.count ?? 0,
    };
  }

  async fetchRecentUsers(limit = 40): Promise<AdminUserRow[]> {
    return this.searchUsers('', limit);
  }

  /**
   * Listado admin con email de Auth.
   * Requiere `admin_list_users.sql` en Supabase.
   */
  async searchUsers(query: string, limit = 40): Promise<AdminUserRow[]> {
    const q = query.replace(/^@/, '').trim();
    const { data, error } = await getSupabase().rpc('admin_list_users', {
      p_query: q.length >= 2 ? q : '',
      p_limit: limit,
    });
    if (error) throw error;
    return (data ?? []).map((row: Record<string, unknown>) => this.mapUser(row));
  }

  async searchHandles(rawQuery: string, limit = 8): Promise<HandleHit[]> {
    const q = rawQuery.replace(/^@/, '').toLowerCase().trim();
    if (q.length < 2) return [];

    const { data, error } = await getSupabase()
      .from('profiles')
      .select('id, handle, display_name, avatar_url, verified')
      .is('suspended_at', null)
      .ilike('handle', `${q}%`)
      .order('handle')
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: String(row.id),
      handle: String(row.handle ?? ''),
      displayName: String(row.display_name ?? ''),
      avatarUrl: (row.avatar_url as string | null) ?? null,
      verified: Boolean(row.verified),
    }));
  }

  async setUserRole(profileId: string, role: 'member' | 'admin'): Promise<void> {
    const { error } = await getSupabase()
      .from('profiles')
      .update({
        role,
        updated_at: new Date().toISOString(),
      })
      .eq('id', profileId);
    if (error) throw error;
  }

  async setVerified(profileId: string, verified: boolean): Promise<void> {
    const { error } = await getSupabase()
      .from('profiles')
      .update({
        verified,
        updated_at: new Date().toISOString(),
      })
      .eq('id', profileId);
    if (error) throw error;
  }

  async suspendProfile(profileId: string, reason: string): Promise<void> {
    const { error } = await getSupabase()
      .from('profiles')
      .update({
        suspended_at: new Date().toISOString(),
        suspended_reason: reason.trim() || 'Suspendido desde panel Junta',
        updated_at: new Date().toISOString(),
      })
      .eq('id', profileId);
    if (error) throw error;
  }

  async unsuspendProfile(profileId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('profiles')
      .update({
        suspended_at: null,
        suspended_reason: null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', profileId);
    if (error) throw error;
  }

  /**
   * Elimina Auth + perfil. Por defecto también borra temas (salvo tablones
   * hermandad / sistema) y comentarios del usuario.
   * Requiere Edge Function `admin-delete-user` desplegada.
   */
  async updateUser(input: {
    profileId: string;
    displayName: string;
    handle: string;
    email: string;
    password?: string | null;
  }): Promise<{
    displayName: string;
    handle: string;
    email: string;
    profileUpdated: boolean;
    emailUpdated: boolean;
    passwordUpdated: boolean;
  }> {
    const body: Record<string, unknown> = {
      profileId: input.profileId,
      displayName: input.displayName.trim(),
      handle: input.handle.replace(/^@/, '').trim().toLowerCase(),
      email: input.email.trim().toLowerCase(),
    };
    if (input.password?.trim()) body['password'] = input.password.trim();

    const { data, error } = await getSupabase().functions.invoke(
      'admin-update-user',
      { body },
    );
    if (error) throw error;
    const payload = data as Record<string, unknown>;
    if (payload?.['error']) {
      throw new Error(String(payload['error']));
    }
    return {
      displayName: String(payload['displayName'] ?? body['displayName']),
      handle: String(payload['handle'] ?? body['handle']),
      email: String(payload['email'] ?? body['email']),
      profileUpdated: Boolean(payload['profileUpdated']),
      emailUpdated: Boolean(payload['emailUpdated']),
      passwordUpdated: Boolean(payload['passwordUpdated']),
    };
  }

  async deleteUser(
    profileId: string,
    options: { deleteContent?: boolean } = {},
  ): Promise<{ deletedTopics: number; deletedReplies: number }> {
    const { data, error } = await getSupabase().functions.invoke(
      'admin-delete-user',
      {
        body: {
          profileId,
          deleteContent: options.deleteContent !== false,
        },
      },
    );
    if (error) throw error;
    const payload = data as Record<string, unknown>;
    if (payload?.['error']) {
      throw new Error(String(payload['error']));
    }
    return {
      deletedTopics: Number(payload['deletedTopics'] ?? 0),
      deletedReplies: Number(payload['deletedReplies'] ?? 0),
    };
  }

  async fetchForumPillars(): Promise<ForumPillarOption[]> {
    const { data, error } = await getSupabase()
      .from('forum_pillars')
      .select('id, name')
      .order('name');
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: String(row.id),
      name: String(row.name ?? row.id),
    }));
  }

  async fetchModeratorAssignments(): Promise<ModeratorAssignment[]> {
    const { data, error } = await getSupabase()
      .from('forum_moderators')
      .select(
        'profile_id, forum_id, assigned_at, profiles!profile_id(handle), forum_pillars(name)',
      )
      .order('assigned_at', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => {
      const profile = row.profiles as { handle?: string } | null;
      const pillar = row.forum_pillars as { name?: string } | null;
      return {
        profileId: String(row.profile_id),
        forumId: String(row.forum_id),
        handle: profile?.handle ?? '—',
        forumName: pillar?.name ?? String(row.forum_id),
        assignedAt: String(row.assigned_at ?? ''),
      };
    });
  }

  async assignModerator(profileId: string, forumId: string): Promise<void> {
    const userId = (await getSupabase().auth.getUser()).data.user?.id ?? null;
    const { error } = await getSupabase().from('forum_moderators').upsert({
      profile_id: profileId,
      forum_id: forumId,
      assigned_by: userId,
    });
    if (error) throw error;
  }

  async removeModerator(profileId: string, forumId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('forum_moderators')
      .delete()
      .eq('profile_id', profileId)
      .eq('forum_id', forumId);
    if (error) throw error;
  }

  async fetchSsLiveReporters(): Promise<SsLiveReporterRow[]> {
    const { data, error } = await getSupabase()
      .from('ss_live_reporters')
      .select('profile_id, assigned_at, note, profiles!profile_id(handle)')
      .order('assigned_at', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => {
      const profile = row.profiles as { handle?: string } | null;
      return {
        profileId: String(row.profile_id),
        handle: profile?.handle ?? '—',
        assignedAt: String(row.assigned_at ?? ''),
        note: String(row.note ?? ''),
      };
    });
  }

  async assignSsLiveReporter(profileId: string, note?: string): Promise<void> {
    const userId = (await getSupabase().auth.getUser()).data.user?.id ?? null;
    const { error } = await getSupabase().from('ss_live_reporters').upsert({
      profile_id: profileId,
      assigned_by: userId,
      note: (note ?? '').slice(0, 200),
      assigned_at: new Date().toISOString(),
    });
    if (error) throw error;
  }

  async removeSsLiveReporter(profileId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('ss_live_reporters')
      .delete()
      .eq('profile_id', profileId);
    if (error) throw error;
  }

  async fetchHermandadBoardTopics(): Promise<HermandadTopicOption[]> {
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select('id, title, excerpt, body, cover_image_url, icon_image_url, created_at')
      .eq('forum_id', 'hermandades')
      .order('title');
    if (error) throw error;
    return (data ?? []).map((row) => {
      const title = String(row.title ?? row.id);
      const parsed = parseHermandadTopicTitle(title);
      return {
        id: String(row.id),
        title,
        processionDay: parsed.processionDay,
        hermandadName: parsed.hermandadName,
        excerpt: String(row.excerpt ?? ''),
        body: String(row.body ?? ''),
        coverImageUrl: (row.cover_image_url as string | null) ?? null,
        iconImageUrl: (row.icon_image_url as string | null) ?? null,
        createdAt: String(row.created_at ?? ''),
      };
    });
  }

  async createHermandadBoard(input: {
    processionDay: string;
    hermandadName: string;
    coverImageUrl?: string | null;
    iconImageUrl?: string | null;
  }): Promise<HermandadTopicOption> {
    const day = input.processionDay.trim();
    const name = input.hermandadName.trim();
    if (!day) throw new Error('Elige el día de estación o Glorias.');
    if (name.length < 2) {
      throw new Error('Indica el nombre de la hermandad (mín. 2 caracteres).');
    }

    const title = hermandadBoardTitle(day, name);
    const template = hermandadBoardTemplate(name, day);
    const id = hermandadBoardTopicId(day, name);
    const cover = input.coverImageUrl?.trim() || null;
    const icon = input.iconImageUrl?.trim() || null;
    const userId = (await getSupabase().auth.getUser()).data.user?.id ?? null;

    const { data, error } = await getSupabase()
      .from('forum_topics')
      .insert({
        id,
        forum_id: 'hermandades',
        author_id: userId,
        author_handle: '@cofradeo',
        title,
        excerpt: template.excerpt,
        body: template.body,
        status: 'published',
        is_pinned: false,
        is_system: false,
        season_key: hermandadBoardSeasonKey(day),
        cover_image_url: cover,
        icon_image_url: icon,
      })
      .select('id, title, excerpt, body, cover_image_url, icon_image_url, created_at')
      .single();
    if (error) {
      if (error.code === '23505') {
        throw new Error('Ya existe un tablón con ese día y nombre.');
      }
      throw error;
    }

    const row = data as Record<string, unknown>;
    const parsed = parseHermandadTopicTitle(String(row['title'] ?? title));
    return {
      id: String(row['id'] ?? id),
      title: String(row['title'] ?? title),
      processionDay: parsed.processionDay,
      hermandadName: parsed.hermandadName,
      excerpt: String(row['excerpt'] ?? ''),
      body: String(row['body'] ?? ''),
      coverImageUrl: (row['cover_image_url'] as string | null) ?? null,
      iconImageUrl: (row['icon_image_url'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
    };
  }

  async updateHermandadBoard(input: {
    id: string;
    processionDay: string;
    hermandadName: string;
    coverImageUrl?: string | null;
    iconImageUrl?: string | null;
    resetBodyToTemplate?: boolean;
  }): Promise<void> {
    const day = input.processionDay.trim();
    const name = input.hermandadName.trim();
    if (!day) throw new Error('Elige el día de estación o Glorias.');
    if (name.length < 2) {
      throw new Error('Indica el nombre de la hermandad (mín. 2 caracteres).');
    }

    const title = hermandadBoardTitle(day, name);
    const template = hermandadBoardTemplate(name, day);
    const patch: Record<string, unknown> = {
      title,
      excerpt: template.excerpt,
      season_key: hermandadBoardSeasonKey(day),
    };
    if (input.resetBodyToTemplate) {
      patch['body'] = template.body;
    }
    if (input.coverImageUrl !== undefined) {
      const v = input.coverImageUrl?.trim() ?? '';
      patch['cover_image_url'] = v || null;
    }
    if (input.iconImageUrl !== undefined) {
      const v = input.iconImageUrl?.trim() ?? '';
      patch['icon_image_url'] = v || null;
    }

    const { error } = await getSupabase()
      .from('forum_topics')
      .update(patch)
      .eq('id', input.id)
      .eq('forum_id', 'hermandades');
    if (error) throw error;
  }

  /** Sube portada o escudo al bucket topic-covers. */
  async uploadHermandadBoardAsset(
    topicId: string,
    kind: 'cover' | 'escudo',
    file: File,
  ): Promise<string> {
    const maxBytes = kind === 'cover' ? 3 * 1024 * 1024 : 1 * 1024 * 1024;
    if (file.size > maxBytes) {
      throw new Error(
        kind === 'cover'
          ? 'La portada no puede superar 3 MB.'
          : 'El escudo no puede superar 1 MB.',
      );
    }
    const ok = ['image/png', 'image/jpeg', 'image/webp'].includes(file.type);
    if (file.type && !ok) {
      throw new Error('Usa PNG, JPEG o WebP.');
    }
    const fromName = (file.name.split('.').pop() || '').toLowerCase();
    let ext = 'jpg';
    if (fromName === 'png' || fromName === 'webp' || fromName === 'jpg' || fromName === 'jpeg') {
      ext = fromName === 'jpeg' ? 'jpg' : fromName;
    } else if (file.type.includes('png')) {
      ext = 'png';
    } else if (file.type.includes('webp')) {
      ext = 'webp';
    }
    const path = `${topicId}/${kind}.${ext}`;
    const { error } = await getSupabase().storage.from('topic-covers').upload(path, file, {
      upsert: true,
      contentType: file.type || 'image/jpeg',
    });
    if (error) throw error;
    const base = getSupabase().storage.from('topic-covers').getPublicUrl(path).data.publicUrl;
    return `${base}?v=${Date.now()}`;
  }

  async deleteHermandadBoard(topicId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('forum_topics')
      .delete()
      .eq('id', topicId)
      .eq('forum_id', 'hermandades');
    if (error) throw error;
  }

  async updateBrotherhoodProfile(input: {
    profileId: string;
    displayName?: string;
    verified?: boolean;
  }): Promise<void> {
    const patch: Record<string, unknown> = {};
    if (input.displayName != null) {
      const name = input.displayName.trim();
      if (name.length < 2) {
        throw new Error('El nombre debe tener al menos 2 caracteres.');
      }
      patch['display_name'] = name;
    }
    if (input.verified != null) patch['verified'] = input.verified;
    if (!Object.keys(patch).length) return;

    const { error } = await getSupabase()
      .from('profiles')
      .update(patch)
      .eq('id', input.profileId)
      .eq('account_type', 'brotherhood');
    if (error) throw error;
  }

  async fetchHermandadAssignments(): Promise<HermandadAssignment[]> {
    const { data, error } = await getSupabase()
      .from('hermandad_topic_accounts')
      .select(
        'profile_id, topic_id, created_at, profiles!profile_id(handle), forum_topics(title)',
      )
      .order('created_at', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => {
      const profile = row.profiles as { handle?: string } | null;
      const topic = row.forum_topics as { title?: string } | null;
      return {
        profileId: String(row.profile_id),
        topicId: String(row.topic_id),
        handle: profile?.handle ?? '—',
        topicTitle: topic?.title ?? String(row.topic_id),
        createdAt: String(row.created_at ?? ''),
      };
    });
  }

  async assignHermandadTopic(profileId: string, topicId: string): Promise<void> {
    const { error } = await getSupabase().from('hermandad_topic_accounts').upsert({
      profile_id: profileId,
      topic_id: topicId,
    });
    if (error) throw error;
  }

  async removeHermandadAssignment(
    profileId: string,
    topicId: string,
  ): Promise<void> {
    const { error } = await getSupabase()
      .from('hermandad_topic_accounts')
      .delete()
      .eq('profile_id', profileId)
      .eq('topic_id', topicId);
    if (error) throw error;
  }

  async createHermandadAccount(input: {
    email: string;
    handle: string;
    displayName: string;
    password?: string | null;
    topicId?: string | null;
  }): Promise<CreatedHermandadAccount> {
    const body: Record<string, unknown> = {
      email: input.email.trim(),
      handle: input.handle.replace(/^@/, '').trim().toLowerCase(),
      displayName: input.displayName.trim(),
    };
    if (input.password?.trim()) body['password'] = input.password.trim();
    if (input.topicId) body['topicId'] = input.topicId;

    const { data, error } = await getSupabase().functions.invoke(
      'create-hermandad-account',
      { body },
    );
    if (error) throw error;
    const payload = data as Record<string, unknown>;
    if (payload?.['error']) {
      throw new Error(String(payload['error']));
    }
    return {
      profileId: String(payload['profileId'] ?? ''),
      handle: String(payload['handle'] ?? body['handle']),
      displayName: String(payload['displayName'] ?? body['displayName']),
      email: String(payload['email'] ?? body['email']),
      topicId: (payload['topicId'] as string | null) ?? null,
      temporaryPassword: (payload['temporaryPassword'] as string | null) ?? null,
    };
  }

  async fetchHermandadAccountCredentials(
    profileId: string,
  ): Promise<HermandadAccountCredentials> {
    const { data, error } = await getSupabase().functions.invoke(
      'manage-hermandad-account',
      { body: { action: 'get', profileId } },
    );
    if (error) throw error;
    const payload = data as Record<string, unknown>;
    if (payload?.['error']) {
      throw new Error(String(payload['error']));
    }
    return {
      profileId: String(payload['profileId'] ?? profileId),
      handle: String(payload['handle'] ?? ''),
      displayName: String(payload['displayName'] ?? ''),
      email: String(payload['email'] ?? ''),
    };
  }

  async updateHermandadAccountCredentials(input: {
    profileId: string;
    email?: string | null;
    password?: string | null;
  }): Promise<HermandadAccountCredentials & {
    passwordUpdated: boolean;
    emailUpdated: boolean;
  }> {
    const body: Record<string, unknown> = {
      action: 'update',
      profileId: input.profileId,
    };
    if (input.email != null) body['email'] = input.email.trim();
    if (input.password?.trim()) body['password'] = input.password.trim();

    const { data, error } = await getSupabase().functions.invoke(
      'manage-hermandad-account',
      { body },
    );
    if (error) throw error;
    const payload = data as Record<string, unknown>;
    if (payload?.['error']) {
      throw new Error(String(payload['error']));
    }
    return {
      profileId: String(payload['profileId'] ?? input.profileId),
      handle: String(payload['handle'] ?? ''),
      displayName: String(payload['displayName'] ?? ''),
      email: String(payload['email'] ?? ''),
      passwordUpdated: Boolean(payload['passwordUpdated']),
      emailUpdated: Boolean(payload['emailUpdated']),
    };
  }

  async fetchBrotherhoodAccounts(limit = 40): Promise<AdminUserRow[]> {
    const { data, error } = await getSupabase()
      .from('profiles')
      .select(
        'id, handle, display_name, role, account_type, verified, suspended_at, suspended_reason, created_at',
      )
      .eq('account_type', 'brotherhood')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapUser(row));
  }

  async submitHermandadAccessRequest(input: {
    hermandadName: string;
    city: string;
    contactName: string;
    contactEmail: string;
    contactPhone?: string;
    message?: string;
    boardKind: HermandadBoardKind;
    processionDay?: string;
    clientFingerprint: string;
    honeypot?: string;
  }): Promise<void> {
    const { error } = await getSupabase().rpc('submit_hermandad_access_request', {
      p_hermandad_name: input.hermandadName.trim(),
      p_city: input.city.trim(),
      p_contact_name: input.contactName.trim(),
      p_contact_email: input.contactEmail.trim().toLowerCase(),
      p_contact_phone: (input.contactPhone ?? '').trim(),
      p_message: (input.message ?? '').trim(),
      p_client_fingerprint: input.clientFingerprint.slice(0, 128),
      p_honeypot: input.honeypot ?? '',
      p_board_kind: input.boardKind,
      p_procession_day:
        input.boardKind === 'glorias'
          ? ''
          : (input.processionDay ?? '').trim(),
    });
    if (error) throw error;
  }

  async fetchHermandadAccessRequests(
    status: HermandadAccessRequestStatus | 'all' = 'pending',
    limit = 50,
  ): Promise<HermandadAccessRequest[]> {
    let query = getSupabase()
      .from('hermandad_access_requests')
      .select(
        'id, hermandad_name, city, contact_name, contact_email, contact_phone, message, board_kind, procession_day, status, review_notes, created_profile_id, created_at, reviewed_at',
      )
      .order('created_at', { ascending: false })
      .limit(limit);
    if (status !== 'all') {
      query = query.eq('status', status);
    }
    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []).map((row) => this.mapAccessRequest(row));
  }

  async reviewHermandadAccessRequest(input: {
    requestId: string;
    status: Exclude<HermandadAccessRequestStatus, 'pending'>;
    notes?: string;
    createdProfileId?: string | null;
  }): Promise<void> {
    const { error } = await getSupabase().rpc('review_hermandad_access_request', {
      p_request_id: input.requestId,
      p_status: input.status,
      p_notes: (input.notes ?? '').trim(),
      p_created_profile_id: input.createdProfileId ?? null,
    });
    if (error) throw error;
  }

  private mapAccessRequest(row: Record<string, unknown>): HermandadAccessRequest {
    const status = String(row['status'] ?? 'pending');
    const kindRaw = String(row['board_kind'] ?? 'semana_santa');
    return {
      id: String(row['id'] ?? ''),
      hermandadName: String(row['hermandad_name'] ?? ''),
      city: String(row['city'] ?? ''),
      contactName: String(row['contact_name'] ?? ''),
      contactEmail: String(row['contact_email'] ?? ''),
      contactPhone: String(row['contact_phone'] ?? ''),
      message: String(row['message'] ?? ''),
      boardKind: kindRaw === 'glorias' ? 'glorias' : 'semana_santa',
      processionDay: String(row['procession_day'] ?? ''),
      status:
        status === 'approved' ||
        status === 'rejected' ||
        status === 'spam' ||
        status === 'pending'
          ? status
          : 'pending',
      reviewNotes: String(row['review_notes'] ?? ''),
      createdProfileId: (row['created_profile_id'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
      reviewedAt: (row['reviewed_at'] as string | null) ?? null,
    };
  }

  private mapUser(row: Record<string, unknown>): AdminUserRow {
    const emailRaw = row['email'];
    const email =
      typeof emailRaw === 'string' && emailRaw.trim()
        ? emailRaw.trim()
        : null;
    return {
      id: String(row['id'] ?? ''),
      handle: String(row['handle'] ?? ''),
      displayName: String(row['display_name'] ?? ''),
      role: row['role'] === 'admin' ? 'admin' : 'member',
      accountType: String(row['account_type'] ?? 'cofrade'),
      verified: Boolean(row['verified']),
      suspendedAt: (row['suspended_at'] as string | null) ?? null,
      suspendedReason: (row['suspended_reason'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
      email,
    };
  }
}
