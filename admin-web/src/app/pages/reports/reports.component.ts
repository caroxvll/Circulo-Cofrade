import { Component, inject, OnInit, signal } from '@angular/core';
import { AuthService } from '../../core/auth/auth.service';
import { ModerationService } from '../../core/moderation/moderation.service';
import { ModerationReportGroup } from '../../core/moderation/moderation.models';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-reports-page',
  standalone: true,
  templateUrl: './reports.component.html',
})
export class ReportsPageComponent implements OnInit {
  private readonly moderation = inject(ModerationService);
  private readonly auth = inject(AuthService);

  readonly groups = signal<ModerationReportGroup[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyKey = signal<string | null>(null);
  readonly expanded = signal<string | null>(null);
  readonly isAdmin = this.auth.isAdmin;
  readonly timeAgo = formatTimeAgo;

  ngOnInit(): void {
    void this.reload();
  }

  typeLabel(type: string): string {
    return (
      {
        profile: 'Perfil',
        topic: 'Tema',
        reply: 'Respuesta',
      }[type] ?? type
    );
  }

  keyOf(group: ModerationReportGroup): string {
    return `${group.targetType}:${group.targetId}`;
  }

  toggle(group: ModerationReportGroup): void {
    const key = this.keyOf(group);
    this.expanded.update((current) => (current === key ? null : key));
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.groups.set(await this.moderation.fetchPendingReportGroups());
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async resolve(group: ModerationReportGroup): Promise<void> {
    const key = this.keyOf(group);
    this.busyKey.set(key);
    try {
      await this.moderation.resolveReportsForTarget(
        group.targetType,
        group.targetId,
      );
      this.groups.update((list) => list.filter((g) => this.keyOf(g) !== key));
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo resolver');
    } finally {
      this.busyKey.set(null);
    }
  }

  async suspend(group: ModerationReportGroup): Promise<void> {
    if (!group.authorProfileId) {
      this.error.set('No hay perfil autor para suspender.');
      return;
    }
    if (!confirm(`¿Suspender a ${group.targetLabel}?`)) return;
    const key = this.keyOf(group);
    this.busyKey.set(key);
    try {
      await this.moderation.suspendProfile(
        group.authorProfileId,
        group.reasonsSummary || 'Suspendido desde panel Junta',
      );
      await this.moderation.resolveReportsForTarget(
        group.targetType,
        group.targetId,
      );
      this.groups.update((list) => list.filter((g) => this.keyOf(g) !== key));
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo suspender');
    } finally {
      this.busyKey.set(null);
    }
  }
}
