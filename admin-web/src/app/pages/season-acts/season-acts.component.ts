import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import {
  CommunityService,
  HermandadAssignment,
  HermandadTopicOption,
  parseHermandadTopicTitle,
} from '../../core/community/community.service';
import { getSupabase } from '../../core/supabase.client';
import {
  SeasonActEvent,
  SeasonActsSnapshot,
  SEASON_ACT_DB_TYPES,
  buildSeasonActsSnapshot,
  currentSeasonActsYear,
  seasonActsRange,
} from '../../core/hermandad/season-acts';

@Component({
  selector: 'app-season-acts-page',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './season-acts.component.html',
  styleUrl: './season-acts.component.scss',
})
export class SeasonActsPageComponent implements OnInit {
  private readonly community = inject(CommunityService);

  readonly year = currentSeasonActsYear();
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly rows = signal<SeasonActsSnapshot[]>([]);

  readonly missingAccount = computed(() =>
    this.rows().filter((r) => !r.hasAccount),
  );
  readonly emptyActs = computed(() =>
    this.rows().filter((r) => r.hasAccount && r.isEmpty),
  );
  readonly partial = computed(() =>
    this.rows().filter((r) => r.hasAccount && !r.isEmpty && !r.isComplete),
  );
  readonly complete = computed(() =>
    this.rows().filter((r) => r.hasAccount && r.isComplete),
  );

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [topics, assignments, events] = await Promise.all([
        this.community.fetchHermandadBoardTopics(),
        this.community.fetchHermandadAssignments(),
        this.fetchSeasonActEvents(),
      ]);
      this.rows.set(this.buildRows(topics, assignments, events));
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? err.message
          : 'No se pudo cargar la cobertura de actos.',
      );
    } finally {
      this.loading.set(false);
    }
  }

  private async fetchSeasonActEvents(): Promise<SeasonActEvent[]> {
    const range = seasonActsRange(this.year);
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .select('id, title, starts_at, event_type, created_by, organizer_label')
      .eq('status', 'published')
      .in('event_type', [...SEASON_ACT_DB_TYPES])
      .gte('starts_at', range.fromIso)
      .lt('starts_at', range.toIso)
      .order('starts_at', { ascending: true })
      .limit(2000);
    if (error) throw error;
    return (data ?? []).map((row) => ({
      id: String(row['id'] ?? ''),
      title: String(row['title'] ?? ''),
      startsAt: String(row['starts_at'] ?? ''),
      eventType: String(row['event_type'] ?? ''),
      createdBy: (row['created_by'] as string | null) ?? null,
      organizerLabel: (row['organizer_label'] as string | null) ?? null,
    }));
  }

  private buildRows(
    topics: HermandadTopicOption[],
    assignments: HermandadAssignment[],
    events: SeasonActEvent[],
  ): SeasonActsSnapshot[] {
    const profileByTopic = new Map(
      assignments.map((a) => [a.topicId, a.profileId] as const),
    );

    const rows = topics.map((topic) => {
      const parsed = parseHermandadTopicTitle(topic.title);
      const name =
        parsed.hermandadName.trim() || topic.title.trim() || topic.id;
      const profileId = profileByTopic.get(topic.id) ?? null;
      return buildSeasonActsSnapshot({
        year: this.year,
        hermandadName: name,
        events,
        topicId: topic.id,
        profileId,
        hasAccount: profileId != null,
      });
    });

    rows.sort((a, b) => {
      const rank = (s: SeasonActsSnapshot) => {
        if (!s.hasAccount) return 0;
        if (s.isEmpty) return 1;
        if (!s.isComplete) return 2;
        return 3;
      };
      const byRank = rank(a) - rank(b);
      if (byRank !== 0) return byRank;
      return a.hermandadName.localeCompare(b.hermandadName, 'es');
    });

    return rows;
  }
}
