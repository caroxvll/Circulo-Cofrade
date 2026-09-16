import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  CommunityService,
  ForumPillarOption,
  HandleHit,
  ModeratorAssignment,
} from '../../core/community/community.service';
import { HandleSearchComponent } from '../../shared/handle-search.component';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-moderators-page',
  standalone: true,
  imports: [FormsModule, HandleSearchComponent],
  templateUrl: './moderators.component.html',
})
export class ModeratorsPageComponent implements OnInit {
  private readonly community = inject(CommunityService);

  readonly assignments = signal<ModeratorAssignment[]>([]);
  readonly pillars = signal<ForumPillarOption[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyKey = signal<string | null>(null);
  readonly assigning = signal(false);
  selected: HandleHit | null = null;
  forumId = '';
  readonly timeAgo = formatTimeAgo;

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [assignments, pillars] = await Promise.all([
        this.community.fetchModeratorAssignments(),
        this.community.fetchForumPillars(),
      ]);
      this.assignments.set(assignments);
      this.pillars.set(pillars);
      if (!this.forumId && pillars.length) this.forumId = pillars[0].id;
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async assign(): Promise<void> {
    if (!this.selected || !this.forumId) {
      this.error.set('Elige usuario y foro.');
      return;
    }
    this.assigning.set(true);
    this.error.set(null);
    try {
      await this.community.assignModerator(this.selected.id, this.forumId);
      this.selected = null;
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo asignar');
    } finally {
      this.assigning.set(false);
    }
  }

  async remove(row: ModeratorAssignment): Promise<void> {
    if (!confirm(`¿Quitar a @${row.handle} de ${row.forumName}?`)) return;
    const key = `${row.profileId}:${row.forumId}`;
    this.busyKey.set(key);
    try {
      await this.community.removeModerator(row.profileId, row.forumId);
      this.assignments.update((list) =>
        list.filter(
          (a) => !(a.profileId === row.profileId && a.forumId === row.forumId),
        ),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo quitar');
    } finally {
      this.busyKey.set(null);
    }
  }
}
