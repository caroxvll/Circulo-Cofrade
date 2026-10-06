import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  CommunityService,
  HandleHit,
  SsLiveReporterRow,
} from '../../core/community/community.service';
import { HandleSearchComponent } from '../../shared/handle-search.component';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-ss-reporters-page',
  standalone: true,
  imports: [FormsModule, HandleSearchComponent],
  templateUrl: './ss-reporters.component.html',
})
export class SsReportersPageComponent implements OnInit {
  private readonly community = inject(CommunityService);

  readonly reporters = signal<SsLiveReporterRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly assigning = signal(false);
  selected: HandleHit | null = null;
  note = '';
  readonly timeAgo = formatTimeAgo;

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.reporters.set(await this.community.fetchSsLiveReporters());
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async assign(): Promise<void> {
    if (!this.selected) {
      this.error.set('Elige un usuario.');
      return;
    }
    this.assigning.set(true);
    this.error.set(null);
    try {
      await this.community.assignSsLiveReporter(
        this.selected.id,
        this.note.trim() || undefined,
      );
      this.selected = null;
      this.note = '';
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo asignar');
    } finally {
      this.assigning.set(false);
    }
  }

  async remove(row: SsLiveReporterRow): Promise<void> {
    if (!confirm(`¿Quitar a @${row.handle} de Informar en Semana Santa?`)) {
      return;
    }
    this.busyId.set(row.profileId);
    try {
      await this.community.removeSsLiveReporter(row.profileId);
      this.reporters.update((list) =>
        list.filter((r) => r.profileId !== row.profileId),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo quitar');
    } finally {
      this.busyId.set(null);
    }
  }
}
