import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import {
  CommunityService,
  HERMANDAD_DIRECTORY_DAYS,
  HermandadAssignment,
  HermandadTopicOption,
  parseHermandadTopicTitle,
} from '../../core/community/community.service';
import { getSupabase } from '../../core/supabase.client';
import {
  DEFAULT_SEASON_PROFILE,
  HermandadSeasonProfile,
  parseSeasonProfile,
  SeasonActEvent,
  SeasonActsSnapshot,
  SeasonPaso,
  SEASON_ACT_DB_TYPES,
  SEASON_ACT_PASO_FILTERS,
  SeasonActPasoFilter,
  buildSeasonActsSnapshot,
  currentSeasonActsYear,
  eventsForPasoSlot,
  filterSeasonActsSnapshots,
  hermandadDayShortLabel,
  matchesPasoFilter,
  seasonActsRange,
  SeasonActMilestone,
  SeasonPasoSlot,
} from '../../core/hermandad/season-acts';

@Component({
  selector: 'app-season-acts-page',
  standalone: true,
  imports: [RouterLink, FormsModule],
  templateUrl: './season-acts.component.html',
  styleUrl: './season-acts.component.scss',
})
export class SeasonActsPageComponent implements OnInit {
  private readonly community = inject(CommunityService);
  private readonly router = inject(Router);

  readonly year = currentSeasonActsYear();
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly rows = signal<SeasonActsSnapshot[]>([]);
  readonly query = signal('');
  readonly dayFilter = signal<string | null>(null);
  readonly pasoFilter = signal<SeasonActPasoFilter | null>(null);
  readonly stationDays = HERMANDAD_DIRECTORY_DAYS;
  readonly shortDayLabel = hermandadDayShortLabel;
  readonly pasoFilters = SEASON_ACT_PASO_FILTERS;
  readonly picker = signal<{
    title: string;
    events: SeasonActEvent[];
  } | null>(null);

  readonly filteredRows = computed(() =>
    filterSeasonActsSnapshots(
      this.rows(),
      this.query(),
      this.dayFilter(),
      this.pasoFilter(),
    ),
  );

  readonly missingAccount = computed(() =>
    this.filteredRows().filter((r) => !r.hasAccount),
  );
  readonly emptyActs = computed(() =>
    this.filteredRows().filter((r) => r.hasAccount && r.isEmpty),
  );
  readonly partial = computed(() =>
    this.filteredRows().filter((r) => r.hasAccount && !r.isEmpty && !r.isComplete),
  );
  readonly complete = computed(() =>
    this.filteredRows().filter((r) => r.hasAccount && r.isComplete),
  );

  readonly dayCounts = computed(() => {
    const counts = new Map<string, number>();
    for (const row of this.rows()) {
      const key = row.processionDay ?? '';
      if (!key) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    return counts;
  });

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [topics, assignments, events, profiles] = await Promise.all([
        this.community.fetchHermandadBoardTopics(),
        this.community.fetchHermandadAssignments(),
        this.fetchSeasonActEvents(),
        this.fetchSeasonProfiles(),
      ]);
      this.rows.set(this.buildRows(topics, assignments, events, profiles));
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
      .select(
        'id, title, starts_at, event_type, created_by, organizer_label, hermandad_topic_id, paso, season_n, with_retranqueo',
      )
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
      hermandadTopicId: (row['hermandad_topic_id'] as string | null) ?? null,
      paso: (row['paso'] as SeasonPaso | null) ?? 'ambos',
      seasonN: (row['season_n'] as number | null) ?? null,
      withRetranqueo: row['with_retranqueo'] === true,
    }));
  }

  private async fetchSeasonProfiles(): Promise<Map<string, HermandadSeasonProfile>> {
    try {
      const { data, error } = await getSupabase()
        .from('hermandad_season_profile')
        .select(
          'topic_id, pasos_layout, iguala_split, ensayo_split, ensayo_count, muda_mode',
        );
      if (error) return new Map();
      return new Map(
        (data ?? []).map((row) => {
          const profile = parseSeasonProfile(row as Record<string, unknown>);
          return [String(row['topic_id']), profile] as const;
        }),
      );
    } catch {
      return new Map();
    }
  }

  setDayFilter(day: string | null): void {
    this.dayFilter.set(day);
  }

  countForDay(day: string): number {
    return this.dayCounts().get(day) ?? 0;
  }

  countForPaso(filter: SeasonActPasoFilter): number {
    return this.rows().filter((row) => matchesPasoFilter(row, filter)).length;
  }

  setPasoFilter(filter: SeasonActPasoFilter | null): void {
    this.pasoFilter.set(filter);
  }

  pasoChipLabel(slot: { label: string; hint?: string | null }): string {
    return slot.hint ? `${slot.label} ${slot.hint}` : slot.label;
  }

  pasoFilterLabel(id: SeasonActPasoFilter | null): string {
    return this.pasoFilters.find((f) => f.id === id)?.label ?? '';
  }

  openMilestoneEvents(row: SeasonActsSnapshot, milestone: SeasonActMilestone): void {
    this.openEvents(
      milestone.events,
      `${row.hermandadName} · ${milestone.label}`,
    );
  }

  openSlotEvents(
    row: SeasonActsSnapshot,
    milestone: SeasonActMilestone,
    slot: SeasonPasoSlot,
    event: Event,
  ): void {
    event.stopPropagation();
    if (!slot.filled) return;
    this.openEvents(
      eventsForPasoSlot(milestone.events, slot),
      `${row.hermandadName} · ${milestone.label} ${slot.label}`,
    );
  }

  openEvents(events: SeasonActEvent[], title: string): void {
    const usable = events.filter((e) => e.id);
    if (!usable.length) return;
    if (usable.length === 1) {
      this.goToEvent(usable[0].id);
      return;
    }
    this.picker.set({ title, events: usable });
  }

  goToEvent(eventId: string): void {
    this.picker.set(null);
    void this.router.navigateByUrl(`/app/eventos?edit=${encodeURIComponent(eventId)}`);
  }

  closePicker(): void {
    this.picker.set(null);
  }

  formatEventWhen(event: SeasonActEvent): string {
    const when = new Date(event.startsAt).toLocaleDateString('es-ES', {
      day: 'numeric',
      month: 'short',
    });
    const paso =
      event.paso === 'cristo'
        ? 'Cristo'
        : event.paso === 'cristo2'
          ? 'Cristo 2'
          : event.paso === 'virgen'
            ? 'Virgen'
            : 'Ambos';
    const n = event.seasonN ? ` · ${event.seasonN}º` : '';
    return `${when} · ${paso}${n}`;
  }

  private buildRows(
    topics: HermandadTopicOption[],
    assignments: HermandadAssignment[],
    events: SeasonActEvent[],
    profiles: Map<string, HermandadSeasonProfile>,
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
        processionDay: parsed.processionDay,
        hasAccount: profileId != null,
        profile: profiles.get(topic.id) ?? DEFAULT_SEASON_PROFILE,
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
