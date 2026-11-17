import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { getSupabase } from '../supabase.client';

export type QuizQuestionStatus =
  | 'draft'
  | 'pending_review'
  | 'approved'
  | 'rejected';

export type QuizOption = 'a' | 'b' | 'c' | 'd';

export interface QuizQuestion {
  id: string;
  prompt: string;
  imageUrl: string | null;
  audioUrl: string | null;
  optionA: string;
  optionB: string;
  optionC: string;
  optionD: string;
  correctOption: QuizOption;
  explanation: string | null;
  status: QuizQuestionStatus;
  createdBy: string | null;
  createdAt: string;
  rejectionReason: string | null;
}

export interface QuizLivePayload {
  state: string;
  roundId: string | null;
  questionId: string | null;
  prompt: string | null;
  closesAt: string | null;
}

export interface QuizSeasonInfo {
  startsOn: string | null;
  message: string | null;
}

const LIVE_VISIBLE_KEY = 'quiz_live_visible';
const SEASON_STARTS_KEY = 'quiz_season_starts_on';
const SEASON_MESSAGE_KEY = 'quiz_season_message';

@Injectable({ providedIn: 'root' })
export class QuizService {
  private readonly auth = inject(AuthService);

  async fetchQuestions(): Promise<QuizQuestion[]> {
    const { data, error } = await getSupabase()
      .from('quiz_questions')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(400);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapQuestion(row as Record<string, unknown>));
  }

  async fetchLaunchedQuestionIds(): Promise<Set<string>> {
    const { data, error } = await getSupabase()
      .from('quiz_rounds')
      .select('question_id')
      .in('status', ['live', 'closed']);
    if (error) throw error;
    return new Set(
      (data ?? [])
        .map((row) => String(row['question_id'] ?? ''))
        .filter(Boolean),
    );
  }

  async fetchLivePayload(): Promise<QuizLivePayload> {
    const { data, error } = await getSupabase().rpc('quiz_get_live_payload');
    if (error) throw error;
    const map = (data ?? {}) as Record<string, unknown>;
    return {
      state: String(map['state'] ?? 'idle'),
      roundId: (map['roundId'] as string | null) ?? (map['round_id'] as string | null) ?? null,
      questionId:
        (map['questionId'] as string | null) ??
        (map['question_id'] as string | null) ??
        null,
      prompt: (map['prompt'] as string | null) ?? null,
      closesAt:
        (map['closesAt'] as string | null) ??
        (map['closes_at'] as string | null) ??
        null,
    };
  }

  async createQuestion(input: {
    prompt: string;
    optionA: string;
    optionB: string;
    optionC: string;
    optionD: string;
    correctOption: QuizOption;
    explanation?: string;
    imageUrl?: string | null;
  }): Promise<void> {
    const uid = this.auth.profile()?.id;
    if (!uid) throw new Error('Sesión no válida.');
    const { error } = await getSupabase().from('quiz_questions').insert({
      prompt: input.prompt.trim(),
      option_a: input.optionA.trim(),
      option_b: input.optionB.trim(),
      option_c: input.optionC.trim(),
      option_d: input.optionD.trim(),
      correct_option: input.correctOption,
      explanation: input.explanation?.trim() || null,
      image_url: input.imageUrl?.trim() || null,
      status: 'pending_review',
      created_by: uid,
    });
    if (error) throw error;
  }

  async setQuestionStatus(
    questionId: string,
    status: QuizQuestionStatus,
    rejectionReason?: string,
  ): Promise<void> {
    const uid = this.auth.profile()?.id ?? null;
    const patch: Record<string, unknown> = {
      status,
      updated_at: new Date().toISOString(),
    };
    if (status === 'approved' || status === 'rejected') {
      patch['reviewed_by'] = uid;
      patch['reviewed_at'] = new Date().toISOString();
      patch['rejection_reason'] = rejectionReason?.trim() || null;
    }
    const { error } = await getSupabase()
      .from('quiz_questions')
      .update(patch)
      .eq('id', questionId);
    if (error) throw error;
  }

  async deleteQuestion(questionId: string): Promise<void> {
    const supabase = getSupabase();
    const { data: row } = await supabase
      .from('quiz_questions')
      .select('image_url, audio_url')
      .eq('id', questionId)
      .maybeSingle();
    const { error } = await supabase.rpc('quiz_delete_question', {
      p_question_id: questionId,
    });
    if (error) throw error;
    await this.removeQuestionMedia(questionId);
    await this.removeStoredUrl(row?.['image_url'] as string | null);
    await this.removeStoredUrl(row?.['audio_url'] as string | null);
  }

  async fetchScheduled(): Promise<Map<string, string>> {
    const { data, error } = await getSupabase()
      .from('quiz_rounds')
      .select('question_id, play_on')
      .eq('status', 'scheduled')
      .order('play_on');
    if (error) throw error;
    const out = new Map<string, string>();
    for (const row of data ?? []) {
      const id = String(row['question_id'] ?? '');
      const day = String(row['play_on'] ?? '');
      if (id && day) out.set(id, day);
    }
    return out;
  }

  async scheduleRound(questionId: string, day: string): Promise<void> {
    const { error } = await getSupabase().rpc('quiz_schedule_round', {
      p_question_id: questionId,
      p_day: day,
    });
    if (error) throw error;
  }

  async cancelScheduledRound(questionId: string): Promise<void> {
    const { error } = await getSupabase().rpc('quiz_cancel_scheduled_round', {
      p_question_id: questionId,
    });
    if (error) throw error;
  }

  private async removeQuestionMedia(questionId: string): Promise<void> {
    const supabase = getSupabase();
    for (const bucket of ['quiz-images', 'quiz-audio']) {
      const { data } = await supabase.storage.from(bucket).list(questionId);
      const paths = (data ?? [])
        .map((file) => file.name)
        .filter((name) => !!name)
        .map((name) => `${questionId}/${name}`);
      if (paths.length === 0) continue;
      await supabase.storage.from(bucket).remove(paths);
    }
  }

  private async removeStoredUrl(url: string | null | undefined): Promise<void> {
    const located = this.locateStoredObject(url);
    if (!located) return;
    await getSupabase().storage.from(located.bucket).remove([located.path]);
  }

  private locateStoredObject(
    url: string | null | undefined,
  ): { bucket: string; path: string } | null {
    const clean = (url ?? '').split('?')[0].trim();
    if (!clean) return null;
    for (const bucket of ['quiz-images', 'quiz-audio']) {
      const marker = `/${bucket}/`;
      const index = clean.indexOf(marker);
      if (index < 0) continue;
      const path = decodeURIComponent(clean.slice(index + marker.length));
      if (!path) return null;
      return { bucket, path };
    }
    return null;
  }

  async launchRound(questionId: string, force = false): Promise<void> {
    const { error } = await getSupabase().rpc('quiz_launch_round', {
      p_question_id: questionId,
      p_force: force,
    });
    if (error) throw error;
  }

  async closeLiveRound(): Promise<number> {
    const { data, error } = await getSupabase().rpc('quiz_close_live_round');
    if (error) throw error;
    const map = (data ?? {}) as Record<string, unknown>;
    return Number(map['closed'] ?? 0);
  }

  async fetchLiveVisible(): Promise<boolean> {
    const { data, error } = await getSupabase()
      .from('app_config')
      .select('value')
      .eq('key', LIVE_VISIBLE_KEY)
      .maybeSingle();
    if (error) throw error;
    const raw = String(data?.['value'] ?? '').trim().toLowerCase();
    if (!raw) return true;
    return raw === 'true' || raw === '1' || raw === 'yes';
  }

  async saveLiveVisible(visible: boolean): Promise<void> {
    const { error } = await getSupabase().from('app_config').upsert({
      key: LIVE_VISIBLE_KEY,
      value: visible ? 'true' : 'false',
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
  }

  async fetchSeasonInfo(): Promise<QuizSeasonInfo> {
    const { data, error } = await getSupabase()
      .from('app_config')
      .select('key, value')
      .in('key', [SEASON_STARTS_KEY, SEASON_MESSAGE_KEY]);
    if (error) throw error;
    let startsOn: string | null = null;
    let message: string | null = null;
    for (const row of data ?? []) {
      const key = String(row['key'] ?? '');
      const value = String(row['value'] ?? '').trim();
      if (key === SEASON_STARTS_KEY) startsOn = value || null;
      if (key === SEASON_MESSAGE_KEY) message = value || null;
    }
    return { startsOn, message };
  }

  async saveSeasonInfo(input: {
    startsOn: string | null;
    message: string | null;
  }): Promise<void> {
    const now = new Date().toISOString();
    const { error } = await getSupabase().from('app_config').upsert([
      {
        key: SEASON_STARTS_KEY,
        value: input.startsOn?.trim() || '',
        updated_at: now,
      },
      {
        key: SEASON_MESSAGE_KEY,
        value: input.message?.trim() || '',
        updated_at: now,
      },
    ]);
    if (error) throw error;
  }

  async uploadQuestionImage(file: File): Promise<string> {
    if (file.size > 500 * 1024) {
      throw new Error('La imagen no puede superar 500 KB.');
    }
    const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
    const path = `${Date.now()}.${ext}`;
    const { error } = await getSupabase().storage.from('quiz-images').upload(path, file, {
      upsert: true,
      contentType: file.type || 'image/jpeg',
    });
    if (error) throw error;
    return getSupabase().storage.from('quiz-images').getPublicUrl(path).data.publicUrl;
  }

  async fetchPrize(yearMonth: string): Promise<{
    active: boolean;
    sponsorName: string;
    title: string;
    description: string;
    imageUrl: string | null;
    address: string;
    claimUntil: string | null;
  } | null> {
    const { data, error } = await getSupabase()
      .from('quiz_month_prizes')
      .select('*')
      .eq('year_month', yearMonth)
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    const row = data as Record<string, unknown>;
    return {
      active: row['active'] === true,
      sponsorName: String(row['sponsor_name'] ?? ''),
      title: String(row['title'] ?? ''),
      description: String(row['description'] ?? ''),
      imageUrl: (row['image_url'] as string | null) ?? null,
      address: String(row['address'] ?? ''),
      claimUntil: (row['claim_until'] as string | null) ?? null,
    };
  }

  async savePrize(input: {
    yearMonth: string;
    active: boolean;
    sponsorName: string;
    title: string;
    description: string;
    imageUrl: string | null;
    address: string;
    claimUntil: string | null;
    updatedBy: string | null;
  }): Promise<void> {
    const { error } = await getSupabase().from('quiz_month_prizes').upsert({
      year_month: input.yearMonth,
      active: input.active,
      sponsor_name: input.sponsorName.trim(),
      title: input.title.trim(),
      description: input.description.trim(),
      image_url: input.imageUrl,
      address: input.address.trim(),
      claim_until: input.claimUntil || null,
      updated_at: new Date().toISOString(),
      updated_by: input.updatedBy,
    });
    if (error) throw error;
  }

  async uploadPrizeImage(yearMonth: string, file: File): Promise<string> {
    if (file.size > 4 * 1024 * 1024) {
      throw new Error('La foto no puede superar 4 MB.');
    }
    const path = `prizes/${yearMonth}/cover.jpg`;
    const { error } = await getSupabase()
      .storage.from('quiz-prizes')
      .upload(path, file, {
        upsert: true,
        contentType: file.type || 'image/jpeg',
      });
    if (error) throw error;
    const url = getSupabase().storage.from('quiz-prizes').getPublicUrl(path).data
      .publicUrl;
    return `${url}?v=${Date.now()}`;
  }

  statusLabel(status: QuizQuestionStatus): string {
    switch (status) {
      case 'draft':
        return 'Borrador';
      case 'pending_review':
        return 'Pendiente';
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
    }
  }

  private mapQuestion(row: Record<string, unknown>): QuizQuestion {
    const correct = String(row['correct_option'] ?? 'a');
    return {
      id: String(row['id'] ?? ''),
      prompt: String(row['prompt'] ?? ''),
      imageUrl: (row['image_url'] as string | null) ?? null,
      audioUrl: (row['audio_url'] as string | null) ?? null,
      optionA: String(row['option_a'] ?? ''),
      optionB: String(row['option_b'] ?? ''),
      optionC: String(row['option_c'] ?? ''),
      optionD: String(row['option_d'] ?? ''),
      correctOption: (['a', 'b', 'c', 'd'].includes(correct)
        ? correct
        : 'a') as QuizOption,
      explanation: (row['explanation'] as string | null) ?? null,
      status: (row['status'] as QuizQuestionStatus) ?? 'draft',
      createdBy: (row['created_by'] as string | null) ?? null,
      createdAt: String(row['created_at'] ?? ''),
      rejectionReason: (row['rejection_reason'] as string | null) ?? null,
    };
  }
}
