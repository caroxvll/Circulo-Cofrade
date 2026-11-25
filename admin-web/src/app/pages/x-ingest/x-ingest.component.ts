import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  CommunityService,
  HERMANDAD_DIRECTORY_DAYS,
  HermandadTopicOption,
} from '../../core/community/community.service';
import { hermandadDayShortLabel } from '../../core/hermandad/season-acts';
import { formatTimeAgo } from '../../core/utils/date';
import {
  XIngestAccount,
  XIngestDraft,
  XIngestService,
  XIngestSettings,
} from '../../core/x-ingest/x-ingest.service';

const CATEGORIES = [
  { value: 'noticia', label: 'Noticias' },
  { value: 'culto', label: 'Cultos' },
  { value: 'acto', label: 'Actos' },
  { value: 'patrimonio', label: 'Patrimonio' },
];

export interface XIngestBoardRow {
  board: HermandadTopicOption;
  account: XIngestAccount | null;
}

export interface XIngestDayGroup {
  day: string;
  items: XIngestBoardRow[];
}

export interface XIngestDraftGroup {
  topicId: string;
  name: string;
  handle: string;
  day: string | null;
  drafts: XIngestDraft[];
}

@Component({
  selector: 'app-x-ingest-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './x-ingest.component.html',
  styleUrl: './x-ingest.component.scss',
})
export class XIngestPageComponent implements OnInit {
  private readonly api = inject(XIngestService);
  private readonly community = inject(CommunityService);

  readonly intervals = this.api.intervals;
  readonly categories = CATEGORIES;
  readonly stationDays = HERMANDAD_DIRECTORY_DAYS;
  readonly shortDayLabel = hermandadDayShortLabel;
  readonly timeAgo = formatTimeAgo;

  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);
  readonly settings = signal<XIngestSettings | null>(null);
  readonly accounts = signal<XIngestAccount[]>([]);
  readonly drafts = signal<XIngestDraft[]>([]);
  readonly boards = signal<HermandadTopicOption[]>([]);
  readonly query = signal('');
  readonly dayFilter = signal<string | null>(null);
  readonly draftQuery = signal('');
  readonly draftDayFilter = signal<string | null>(null);
  readonly draftTopicFilter = signal<string | null>(null);
  readonly selectedDraftId = signal<string | null>(null);
  readonly collapsedTopics = signal<Set<string>>(new Set());
  readonly handles: Record<string, string> = {};

  readonly rows = computed<XIngestBoardRow[]>(() => {
    const byTopic = new Map(this.accounts().map((a) => [a.topicId, a]));
    return this.boards().map((board) => ({
      board,
      account: byTopic.get(board.id) ?? null,
    }));
  });

  readonly filteredRows = computed(() => {
    const q = this.query().trim().toLowerCase();
    const day = this.dayFilter();
    return this.rows().filter((row) => {
      if (day && row.board.processionDay !== day) return false;
      if (!q) return true;
      const hay = `${row.board.hermandadName} ${row.account?.handle ?? ''}`.toLowerCase();
      return hay.includes(q);
    });
  });

  readonly groups = computed<XIngestDayGroup[]>(() => {
    const rows = this.filteredRows();
    const out: XIngestDayGroup[] = [];
    for (const day of this.stationDays) {
      const items = rows.filter((r) => r.board.processionDay === day);
      if (items.length) out.push({ day, items });
    }
    const other = rows.filter(
      (r) =>
        !r.board.processionDay ||
        !(this.stationDays as readonly string[]).includes(r.board.processionDay),
    );
    if (other.length) out.push({ day: 'Otros', items: other });
    return out;
  });

  readonly activeCount = computed(
    () => this.accounts().filter((a) => a.ingestEnabled).length,
  );
  readonly pausedCount = computed(
    () => this.accounts().filter((a) => !a.ingestEnabled).length,
  );
  readonly missingCount = computed(
    () => Math.max(0, this.boards().length - this.accounts().length),
  );

  readonly filteredDrafts = computed(() => {
    const q = this.draftQuery().trim().toLowerCase();
    const day = this.draftDayFilter();
    const topic = this.draftTopicFilter();
    return this.drafts().filter((draft) => {
      if (topic && draft.topicId !== topic) return false;
      if (day && draft.processionDay !== day) return false;
      if (!q) return true;
      const hay = `${draft.hermandadName} ${draft.handle} ${draft.body}`.toLowerCase();
      return hay.includes(q);
    });
  });

  readonly draftGroups = computed<XIngestDraftGroup[]>(() => {
    const map = new Map<string, XIngestDraftGroup>();
    for (const draft of this.filteredDrafts()) {
      let group = map.get(draft.topicId);
      if (!group) {
        group = {
          topicId: draft.topicId,
          name: draft.hermandadName,
          handle: draft.handle,
          day: draft.processionDay,
          drafts: [],
        };
        map.set(draft.topicId, group);
      }
      group.drafts.push(draft);
    }
    return [...map.values()].sort((a, b) => {
      if (b.drafts.length !== a.drafts.length) return b.drafts.length - a.drafts.length;
      return a.name.localeCompare(b.name, 'es');
    });
  });

  readonly draftDays = computed(() => {
    const present = new Set(
      this.drafts()
        .map((d) => d.processionDay)
        .filter((day): day is string => Boolean(day)),
    );
    return this.stationDays.filter((day) => present.has(day));
  });

  readonly selectedDraft = computed<XIngestDraft | null>(() => {
    const id = this.selectedDraftId();
    const list = this.filteredDrafts();
    if (id) {
      const match = list.find((d) => d.id === id);
      if (match) return match;
    }
    return list[0] ?? null;
  });

  readonly draftFilterName = computed(() => {
    const topicId = this.draftTopicFilter();
    if (!topicId) return null;
    return this.drafts().find((d) => d.topicId === topicId)?.hermandadName ?? null;
  });

  async ngOnInit(): Promise<void> {
    await this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [settings, accounts, drafts, boards] = await Promise.all([
        this.api.fetchSettings(),
        this.api.fetchAccounts(),
        this.api.fetchDrafts(),
        this.community.fetchHermandadBoardTopics(),
      ]);
      this.settings.set(settings);
      this.accounts.set(accounts);
      this.drafts.set(drafts);
      this.boards.set(boards);
    } catch (e) {
      this.error.set(
        this.friendlyError(
          e instanceof Error
            ? e.message
            : 'No se pudo cargar Redes X. ¿Ejecutaste x_ingest.sql?',
        ),
      );
    } finally {
      this.loading.set(false);
    }
  }

  setDayFilter(day: string | null): void {
    this.dayFilter.set(day);
  }

  countForDay(day: string): number {
    return this.rows().filter((r) => r.board.processionDay === day).length;
  }

  activeForDay(day: string): number {
    return this.rows().filter(
      (r) => r.board.processionDay === day && r.account?.ingestEnabled,
    ).length;
  }

  intervalLabel(minutes: number): string {
    if (minutes < 60) return `${minutes} min`;
    if (minutes === 60) return '1 hora';
    return `${minutes / 60} horas`;
  }

  lastRunLabel(settings: XIngestSettings): string {
    if (!settings.lastRunAt) return 'Aún no ha corrido';
    const extra = [
      settings.lastRunForced ? 'a mano' : null,
      settings.lastRunNewPosts > 0 ? `${settings.lastRunNewPosts} nuevos` : null,
    ]
      .filter(Boolean)
      .join(' · ');
    return `Última pasada ${this.timeAgo(settings.lastRunAt)}${extra ? ` · ${extra}` : ''}`;
  }

  friendlyError(raw: string | null | undefined): string {
    if (!raw) return '';
    const text = raw.toLowerCase();
    if (text.includes('credits depleted') || text.includes('402')) {
      return 'Sin créditos en X. Recarga en Facturación → Créditos y vuelve a lanzar.';
    }
    if (text.includes('x_bearer_token')) {
      return 'Falta el secreto X_BEARER_TOKEN en la Edge Function.';
    }
    if (text.includes('x_ingest.sql')) {
      return 'Falta ejecutar supabase/x_ingest.sql en este proyecto.';
    }
    return raw.length > 180 ? `${raw.slice(0, 177)}…` : raw;
  }

  statusOf(row: XIngestBoardRow): 'active' | 'paused' | 'error' | 'missing' {
    const account = row.account;
    if (!account) return 'missing';
    if (account.lastError) return 'error';
    return account.ingestEnabled ? 'active' : 'paused';
  }

  statusLabel(row: XIngestBoardRow): string {
    return {
      active: 'Activa',
      paused: 'Pausada',
      error: 'Error',
      missing: 'Sin X',
    }[this.statusOf(row)];
  }

  categoryLabel(value: string): string {
    return this.categories.find((c) => c.value === value)?.label ?? 'Noticias';
  }

  excerpt(text: string, max = 140): string {
    const clean = text.replace(/\s+/g, ' ').trim();
    if (clean.length <= max) return clean || 'Sin texto';
    return `${clean.slice(0, max - 1)}…`;
  }

  draftCountFor(topicId: string): number {
    return this.drafts().filter((d) => d.topicId === topicId).length;
  }

  isGroupCollapsed(topicId: string): boolean {
    return this.collapsedTopics().has(topicId);
  }

  toggleGroup(topicId: string): void {
    const next = new Set(this.collapsedTopics());
    if (next.has(topicId)) next.delete(topicId);
    else next.add(topicId);
    this.collapsedTopics.set(next);
  }

  selectDraft(draft: XIngestDraft): void {
    this.selectedDraftId.set(draft.id);
  }

  isSelected(draft: XIngestDraft): boolean {
    return this.selectedDraft()?.id === draft.id;
  }

  setDraftDayFilter(day: string | null): void {
    this.draftDayFilter.set(day);
    this.selectedDraftId.set(null);
  }

  setDraftTopicFilter(topicId: string | null): void {
    this.draftTopicFilter.set(topicId);
    this.selectedDraftId.set(null);
  }

  openInboxFor(topicId: string): void {
    this.draftTopicFilter.set(topicId);
    const first = this.drafts().find((d) => d.topicId === topicId);
    this.selectedDraftId.set(first?.id ?? null);
    this.scrollToDrafts();
  }

  scrollToDrafts(): void {
    document.getElementById('borradores')?.scrollIntoView({
      behavior: 'smooth',
      block: 'start',
    });
  }

  private selectNextAfter(removedId: string, topicId: string): void {
    const remaining = this.drafts().filter((d) => d.id !== removedId);
    const same = remaining.find((d) => d.topicId === topicId);
    this.selectedDraftId.set(same?.id ?? remaining[0]?.id ?? null);
  }

  async setEnabled(enabled: boolean): Promise<void> {
    const current = this.settings();
    if (!current) return;
    await this.saveSettings({ ...current, enabled });
  }

  async setInterval(minutes: number): Promise<void> {
    const current = this.settings();
    if (!current) return;
    await this.saveSettings({ ...current, intervalMinutes: minutes });
  }

  private async saveSettings(next: XIngestSettings): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.api.saveSettings({
        enabled: next.enabled,
        intervalMinutes: next.intervalMinutes,
        maxPostsPerAccount: next.maxPostsPerAccount,
      });
      this.settings.set(await this.api.fetchSettings());
    } catch (e) {
      this.error.set(
        this.friendlyError(
          e instanceof Error ? e.message : 'No se pudieron guardar los ajustes',
        ),
      );
    } finally {
      this.saving.set(false);
    }
  }

  async run(opts: { skipBacklog?: boolean; accountId?: string } = {}): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      const result = await this.api.runPull({
        force: true,
        skipBacklog: opts.skipBacklog,
        accountId: opts.accountId,
      });
      await this.reload();
      if (opts.skipBacklog) return;
      if (result.skipped) {
        this.error.set(this.friendlyError(result.message ?? 'Job omitido'));
      }
    } catch (e) {
      this.error.set(
        this.friendlyError(
          e instanceof Error
            ? e.message
            : 'No se pudo lanzar. ¿Desplegaste x-ingest-pull?',
        ),
      );
    } finally {
      this.saving.set(false);
    }
  }

  async addAccount(topicId: string): Promise<void> {
    const handle = (this.handles[topicId] ?? '').trim();
    if (!topicId || !handle) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.api.upsertAccount({ topicId, handle });
      this.handles[topicId] = '';
      this.accounts.set(await this.api.fetchAccounts());
    } catch (e) {
      this.error.set(
        this.friendlyError(
          e instanceof Error ? e.message : 'No se pudo enlazar la cuenta',
        ),
      );
    } finally {
      this.saving.set(false);
    }
  }

  async toggleAccount(account: XIngestAccount, enabled: boolean): Promise<void> {
    this.saving.set(true);
    try {
      await this.api.setAccountEnabled(account.id, enabled);
      this.accounts.set(await this.api.fetchAccounts());
    } catch (e) {
      this.error.set(
        this.friendlyError(
          e instanceof Error ? e.message : 'No se pudo pausar la cuenta',
        ),
      );
    } finally {
      this.saving.set(false);
    }
  }

  async removeAccount(account: XIngestAccount): Promise<void> {
    this.saving.set(true);
    try {
      await this.api.deleteAccount(account.id);
      this.accounts.set(await this.api.fetchAccounts());
    } catch (e) {
      this.error.set(
        this.friendlyError(
          e instanceof Error ? e.message : 'No se pudo quitar la cuenta',
        ),
      );
    } finally {
      this.saving.set(false);
    }
  }

  async publish(
    draft: XIngestDraft,
    body: string,
    category: string,
    topicId: string,
  ): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.api.publishDraft({
        draftId: draft.id,
        topicId,
        category,
        body,
      });
      this.selectNextAfter(draft.id, topicId);
      this.drafts.set(await this.api.fetchDrafts());
    } catch (e) {
      this.error.set(
        this.friendlyError(e instanceof Error ? e.message : 'No se pudo publicar'),
      );
    } finally {
      this.saving.set(false);
    }
  }

  async discard(draft: XIngestDraft): Promise<void> {
    this.saving.set(true);
    try {
      await this.api.discardDraft(draft.id);
      this.selectNextAfter(draft.id, draft.topicId);
      this.drafts.set(await this.api.fetchDrafts());
    } catch (e) {
      this.error.set(
        this.friendlyError(e instanceof Error ? e.message : 'No se pudo descartar'),
      );
    } finally {
      this.saving.set(false);
    }
  }

  async discardGroup(group: XIngestDraftGroup): Promise<void> {
    const ok = confirm(
      `¿Descartar los ${group.drafts.length} borradores de ${group.name}? No se publican.`,
    );
    if (!ok) return;
    this.saving.set(true);
    try {
      await this.api.discardDraftsForTopic(group.topicId);
      if (this.selectedDraft()?.topicId === group.topicId) {
        this.selectedDraftId.set(null);
      }
      this.drafts.set(await this.api.fetchDrafts());
    } catch (e) {
      this.error.set(
        this.friendlyError(
          e instanceof Error ? e.message : 'No se pudo descartar el lote',
        ),
      );
    } finally {
      this.saving.set(false);
    }
  }
}
