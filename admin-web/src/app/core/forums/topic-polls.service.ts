import { Injectable } from '@angular/core';
import { getSupabase } from '../supabase.client';

export interface TopicPollOptionView {
  id: string;
  label: string;
  sortOrder: number;
  voteCount: number;
}

export interface TopicPollView {
  id: string;
  topicId: string;
  question: string;
  closedAt: string | null;
  options: TopicPollOptionView[];
  totalVotes: number;
}

@Injectable({ providedIn: 'root' })
export class TopicPollsService {
  async fetchPollForTopic(topicId: string): Promise<TopicPollView | null> {
    const { data: poll, error } = await getSupabase()
      .from('topic_polls')
      .select('id, topic_id, question, closed_at')
      .eq('topic_id', topicId)
      .maybeSingle();
    if (error) throw error;
    if (!poll) return null;

    const pollId = String(poll['id']);

    const [{ data: options, error: optErr }, { data: votes, error: voteErr }] =
      await Promise.all([
        getSupabase()
          .from('topic_poll_options')
          .select('id, label, sort_order')
          .eq('poll_id', pollId)
          .order('sort_order'),
        getSupabase()
          .from('topic_poll_votes')
          .select('option_id')
          .eq('poll_id', pollId),
      ]);
    if (optErr) throw optErr;
    if (voteErr) throw voteErr;

    const counts = new Map<string, number>();
    for (const row of votes ?? []) {
      const optionId = String(row['option_id']);
      counts.set(optionId, (counts.get(optionId) ?? 0) + 1);
    }

    const mappedOptions: TopicPollOptionView[] = (options ?? []).map((row) => {
      const id = String(row['id']);
      return {
        id,
        label: String(row['label'] ?? '').trim(),
        sortOrder: Number(row['sort_order'] ?? 0),
        voteCount: counts.get(id) ?? 0,
      };
    });

    const totalVotes = mappedOptions.reduce((sum, o) => sum + o.voteCount, 0);

    return {
      id: pollId,
      topicId: String(poll['topic_id']),
      question: String(poll['question'] ?? '').trim(),
      closedAt: (poll['closed_at'] as string | null) ?? null,
      options: mappedOptions,
      totalVotes,
    };
  }

  /** Carga encuestas de varios temas (cola de moderación). */
  async fetchPollsByTopicIds(topicIds: string[]): Promise<Map<string, TopicPollView>> {
    const result = new Map<string, TopicPollView>();
    const unique = [...new Set(topicIds.filter(Boolean))];
    if (unique.length === 0) return result;

    await Promise.all(
      unique.map(async (topicId) => {
        try {
          const poll = await this.fetchPollForTopic(topicId);
          if (poll) result.set(topicId, poll);
        } catch {
          // Tema sin encuesta o RLS: se omite.
        }
      }),
    );
    return result;
  }

  async closePoll(pollId: string): Promise<void> {
    const { error } = await getSupabase().rpc('close_topic_poll', {
      p_poll_id: pollId,
    });
    if (error) throw error;
  }

  async deletePoll(pollId: string): Promise<void> {
    const { error } = await getSupabase().rpc('delete_topic_poll', {
      p_poll_id: pollId,
    });
    if (error) throw error;
  }
}
