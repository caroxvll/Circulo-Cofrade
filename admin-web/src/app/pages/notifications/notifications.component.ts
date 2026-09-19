import { DatePipe } from '@angular/common';
import {
  Component,
  OnDestroy,
  OnInit,
  computed,
  inject,
  signal,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  DispatchJobRow,
  DispatchOverview,
  NotificationsAdminService,
  NotificationsOverview,
  PushUserFilter,
  PushUserRow,
  TABLE_PREF_KEYS,
  UserNotifDiag,
} from '../../core/notifications/notifications-admin.service';
import { HandleHit } from '../../core/community/community.service';
import { HandleSearchComponent } from '../../shared/handle-search.component';

type NotifTab = 'coverage' | 'queue';

@Component({
  selector: 'app-notifications-page',
  standalone: true,
  imports: [FormsModule, HandleSearchComponent, DatePipe],
  templateUrl: './notifications.component.html',
  styleUrl: './notifications.component.scss',
})
export class NotificationsPageComponent implements OnInit, OnDestroy {
  private readonly api = inject(NotificationsAdminService);
  private queueTimer: ReturnType<typeof setInterval> | null = null;

  readonly pageSize = 50;
  readonly tab = signal<NotifTab>('coverage');
  readonly days = signal(30);
  readonly overview = signal<NotificationsOverview | null>(null);
  readonly diag = signal<UserNotifDiag | null>(null);
  readonly pushUsers = signal<PushUserRow[]>([]);
  readonly pushUsersTotal = signal(0);
  readonly pushPage = signal(0);
  readonly pushFilter = signal<PushUserFilter>('on');
  readonly loading = signal(true);
  readonly listLoading = signal(false);
  readonly diagLoading = signal(false);
  readonly queueLoading = signal(false);
  readonly queueBusy = signal(false);
  readonly error = signal<string | null>(null);
  readonly queueInfo = signal<string | null>(null);
  readonly dispatchOverview = signal<DispatchOverview | null>(null);
  readonly dispatchJobs = signal<DispatchJobRow[]>([]);
  readonly liveQueue = signal(true);

  selected: HandleHit | null = null;
  pushSearch = '';

  readonly typeLabel = (t: string) => this.api.typeLabel(t);
  readonly prefLabel = (k: string) => this.api.prefLabel(k);
  readonly prefShort = (k: string) => this.api.prefShort(k);
  readonly platformLabel = (p: string) => this.api.platformLabel(p);
  readonly kindLabel = (k: string) => this.api.kindLabel(k);
  readonly statusLabel = (s: string) => this.api.statusLabel(s);
  readonly tablePrefKeys = TABLE_PREF_KEYS;

  readonly totalPages = computed(() =>
    Math.max(1, Math.ceil(this.pushUsersTotal() / this.pageSize)),
  );

  readonly pageLabel = computed(() => {
    const total = this.pushUsersTotal();
    if (total === 0) return '0 usuarios';
    const from = this.pushPage() * this.pageSize + 1;
    const to = Math.min(total, (this.pushPage() + 1) * this.pageSize);
    return `${this.formatInt(from)}–${this.formatInt(to)} de ${this.formatInt(total)}`;
  });

  ngOnInit(): void {
    void this.reload();
  }

  ngOnDestroy(): void {
    this.stopQueueLive();
  }

  setTab(tab: NotifTab): void {
    this.tab.set(tab);
    this.error.set(null);
    this.queueInfo.set(null);
    if (tab === 'queue') {
      void this.reloadQueue();
      this.startQueueLive();
    } else {
      this.stopQueueLive();
    }
  }

  startQueueLive(): void {
    this.stopQueueLive();
    if (!this.liveQueue()) return;
    this.queueTimer = setInterval(() => {
      if (this.tab() === 'queue' && this.liveQueue() && !this.queueBusy()) {
        void this.reloadQueue(true);
      }
    }, 5000);
  }

  stopQueueLive(): void {
    if (this.queueTimer) {
      clearInterval(this.queueTimer);
      this.queueTimer = null;
    }
  }

  toggleLiveQueue(): void {
    this.liveQueue.update((v) => !v);
    if (this.liveQueue()) this.startQueueLive();
    else this.stopQueueLive();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    this.pushPage.set(0);
    try {
      this.overview.set(await this.api.fetchOverview(this.days()));
      await this.reloadPushUsers();
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste staff_notifications_overview.sql?`
          : 'No se pudo cargar',
      );
    } finally {
      this.loading.set(false);
    }
  }

  async reloadQueue(silent = false): Promise<void> {
    if (!silent) this.queueLoading.set(true);
    if (!silent) this.error.set(null);
    try {
      const [overview, jobs] = await Promise.all([
        this.api.fetchDispatchOverview(),
        this.api.listDispatchJobs(50),
      ]);
      this.dispatchOverview.set(overview);
      this.dispatchJobs.set(jobs);
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste notification_dispatch_admin.sql (y v1/v2/cron)?`
          : 'No se pudo cargar la cola',
      );
    } finally {
      this.queueLoading.set(false);
    }
  }

  async processNow(): Promise<void> {
    this.queueBusy.set(true);
    this.queueInfo.set(null);
    this.error.set(null);
    try {
      const result = await this.api.processDispatchNow();
      this.queueInfo.set(
        result.processedTotal > 0
          ? `Procesados ${result.processedTotal} avisos en este lote.`
          : 'Cola vacía o sin más destinatarios en este tick.',
      );
      await this.reloadQueue(true);
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo procesar la cola',
      );
    } finally {
      this.queueBusy.set(false);
    }
  }

  async retryFailed(): Promise<void> {
    this.queueBusy.set(true);
    this.queueInfo.set(null);
    this.error.set(null);
    try {
      const n = await this.api.retryFailedDispatchJobs();
      this.queueInfo.set(
        n > 0
          ? `${n} trabajo(s) fallido(s) vueltos a la cola.`
          : 'No había trabajos fallidos.',
      );
      await this.reloadQueue(true);
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudieron reintentar',
      );
    } finally {
      this.queueBusy.set(false);
    }
  }

  async reloadApiSchema(): Promise<void> {
    this.queueBusy.set(true);
    this.queueInfo.set(null);
    this.error.set(null);
    try {
      await this.api.reloadApiSchema();
      this.queueInfo.set(
        'API recargada. Si faltaba alguna función nueva, ya debería verse.',
      );
      await this.reloadQueue(true);
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Reejecutaste notification_dispatch_admin.sql?`
          : 'No se pudo recargar el esquema',
      );
    } finally {
      this.queueBusy.set(false);
    }
  }

  statusCount(status: string): number {
    return Number(this.dispatchOverview()?.byStatus?.[status] ?? 0);
  }

  async reloadPushUsers(): Promise<void> {
    this.listLoading.set(true);
    try {
      const page = await this.api.listPushUsers({
        filter: this.pushFilter(),
        search: this.pushSearch,
        limit: this.pageSize,
        offset: this.pushPage() * this.pageSize,
      });
      this.pushUsers.set(page.rows);
      this.pushUsersTotal.set(page.total);
      const maxPage = Math.max(0, Math.ceil(page.total / this.pageSize) - 1);
      if (this.pushPage() > maxPage) {
        this.pushPage.set(maxPage);
      }
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Reejecutaste staff_notifications_overview.sql?`
          : 'No se pudo listar usuarios',
      );
    } finally {
      this.listLoading.set(false);
    }
  }

  setDays(days: number): void {
    this.days.set(days);
    void this.reload();
  }

  setPushFilter(filter: PushUserFilter): void {
    this.pushFilter.set(filter);
    this.pushPage.set(0);
    void this.reloadPushUsers();
  }

  searchPushUsers(): void {
    this.pushPage.set(0);
    void this.reloadPushUsers();
  }

  goPage(delta: number): void {
    const next = Math.min(
      this.totalPages() - 1,
      Math.max(0, this.pushPage() + delta),
    );
    if (next === this.pushPage()) return;
    this.pushPage.set(next);
    void this.reloadPushUsers();
  }

  openUserFromList(row: PushUserRow): void {
    this.selected = {
      id: row.userId,
      handle: row.handle,
      displayName: row.displayName ?? row.handle,
      avatarUrl: null,
      verified: false,
    };
    void this.loadDiag(row.handle);
  }

  onUserPick(hit: HandleHit | null): void {
    this.selected = hit;
    if (hit) void this.loadDiag(hit.handle);
  }

  async loadDiag(handle: string): Promise<void> {
    this.diagLoading.set(true);
    this.error.set(null);
    try {
      this.diag.set(await this.api.fetchUserDiag(handle));
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo diagnosticar el usuario',
      );
    } finally {
      this.diagLoading.set(false);
    }
  }

  prefEntries(prefs: Record<string, unknown> | null | undefined): {
    key: string;
    on: boolean;
  }[] {
    if (!prefs) return [];
    return Object.entries(prefs)
      .filter(([key]) => key !== 'user_id' && key !== 'updated_at')
      .map(([key, value]) => ({
        key,
        on: value === true || value === 'true',
      }))
      .sort((a, b) => a.key.localeCompare(b.key));
  }

  rowPrefOn(row: PushUserRow, key: string): boolean | null {
    if (!row.prefs) return null;
    const value = row.prefs[key];
    if (value === undefined || value === null) return null;
    return value === true || value === 'true';
  }

  formatInt(n: number): string {
    return new Intl.NumberFormat('es-ES').format(n);
  }

  pct(part: number, total: number): number {
    if (total <= 0) return 0;
    return Math.round((part / total) * 1000) / 10;
  }

  /** Ángulo CSS del anillo (0–360). */
  ringDeg(part: number, total: number): number {
    if (total <= 0) return 0;
    return Math.min(360, (part / total) * 360);
  }

  pushRingBg(): string {
    const o = this.overview();
    if (!o) return '#e8dfd4';
    const on = this.ringDeg(o.pushEnabledUsers, o.totalUsers);
    return `conic-gradient(var(--burgundy) 0deg ${on}deg, #e8dfd4 ${on}deg 360deg)`;
  }

  deviceReadyPct(): number {
    const o = this.overview();
    if (!o) return 0;
    return this.pct(o.pushOnWithDevice, Math.max(1, o.pushEnabledUsers));
  }

  deviceRingBg(): string {
    const o = this.overview();
    if (!o) return '#e8dfd4';
    const base = Math.max(1, o.pushEnabledUsers);
    const ready = this.ringDeg(o.pushOnWithDevice, base);
    const gap = this.ringDeg(o.pushOnWithDevice + o.pushOnNoDevice, base);
    return `conic-gradient(#2f6b4f 0deg ${ready}deg, #c47a2c ${ready}deg ${gap}deg, #e8dfd4 ${gap}deg 360deg)`;
  }

  platformRingBg(): string {
    const o = this.overview();
    if (!o) return '#e8dfd4';
    const entries = this.platformEntries(o.tokensByPlatform);
    const total = entries.reduce((s, e) => s + e.count, 0);
    if (total <= 0) return 'conic-gradient(#e8dfd4 0deg 360deg)';
    const palette = ['#7a0814', '#2f6b4f', '#3d5a80', '#c47a2c', '#6b5b7a'];
    let cursor = 0;
    const parts: string[] = [];
    entries.forEach((entry, i) => {
      const next = cursor + (entry.count / total) * 360;
      parts.push(`${palette[i % palette.length]} ${cursor}deg ${next}deg`);
      cursor = next;
    });
    return `conic-gradient(${parts.join(', ')})`;
  }

  hasActivePrefChips(row: PushUserRow): boolean {
    return this.tablePrefKeys.some((key) => this.rowPrefOn(row, key) === true);
  }

  platformEntries(
    map: Record<string, number>,
  ): { platform: string; count: number }[] {
    return Object.entries(map)
      .map(([platform, count]) => ({ platform, count: Number(count) }))
      .sort((a, b) => b.count - a.count);
  }

  dayBarPercent(count: number, rows: { count: number }[]): number {
    const max = Math.max(1, ...rows.map((r) => r.count));
    return (count / max) * 100;
  }

  coverageHint(row: PushUserRow): string {
    if (!row.pushEnabled) return 'Avisos apagados';
    if (row.tokenCount <= 0) return 'Sin móvil registrado';
    return row.tokenCount === 1
      ? '1 dispositivo'
      : `${row.tokenCount} dispositivos`;
  }
}
