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

export interface HermandadTopicOption {
  id: string;
  title: string;
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
    const { data, error } = await getSupabase()
      .from('profiles')
      .select(
        'id, handle, display_name, role, account_type, verified, suspended_at, suspended_reason, created_at',
      )
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapUser(row));
  }

  async searchUsers(query: string, limit = 40): Promise<AdminUserRow[]> {
    const q = query.replace(/^@/, '').trim();
    if (q.length < 2) return this.fetchRecentUsers(limit);

    const { data, error } = await getSupabase()
      .from('profiles')
      .select(
        'id, handle, display_name, role, account_type, verified, suspended_at, suspended_reason, created_at',
      )
      .or(`handle.ilike.%${q}%,display_name.ilike.%${q}%`)
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapUser(row));
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

  async fetchHermandadBoardTopics(): Promise<HermandadTopicOption[]> {
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select('id, title')
      .eq('forum_id', 'hermandades')
      .order('title');
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: String(row.id),
      title: String(row.title ?? row.id),
    }));
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

  private mapUser(row: Record<string, unknown>): AdminUserRow {
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
    };
  }
}
