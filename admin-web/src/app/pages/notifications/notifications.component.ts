import { DatePipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  NotificationsAdminService,
  NotificationsOverview,
  PushUserFilter,
  PushUserRow,
  TABLE_PREF_KEYS,
  UserNotifDiag,
} from '../../core/notifications/notifications-admin.service';
import { HandleHit } from '../../core/community/community.service';
import { HandleSearchComponent } from '../../shared/handle-search.component';

@Component({
  selector: 'app-notifications-page',
  standalone: true,
  imports: [FormsModule, HandleSearchComponent, DatePipe],
  templateUrl: './notifications.component.html',
  styleUrl: './notifications.component.scss',
})
export class NotificationsPageComponent implements OnInit {
  private readonly api = inject(NotificationsAdminService);

  readonly pageSize = 50;
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
  readonly error = signal<string | null>(null);

  selected: HandleHit | null = null;
  pushSearch = '';

  readonly typeLabel = (t: string) => this.api.typeLabel(t);
  readonly prefLabel = (k: string) => this.api.prefLabel(k);
  readonly prefShort = (k: string) => this.api.prefShort(k);
  readonly platformLabel = (p: string) => this.api.platformLabel(p);
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
