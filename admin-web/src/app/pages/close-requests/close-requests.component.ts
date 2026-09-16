import { Component, inject, OnInit, signal } from '@angular/core';
import { ModerationService } from '../../core/moderation/moderation.service';
import { ModerationTopic } from '../../core/moderation/moderation.models';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-close-requests-page',
  standalone: true,
  templateUrl: './close-requests.component.html',
})
export class CloseRequestsPageComponent implements OnInit {
  private readonly moderation = inject(ModerationService);

  readonly topics = signal<ModerationTopic[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly timeAgo = formatTimeAgo;

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.topics.set(await this.moderation.fetchCloseRequestedTopics());
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async approve(topic: ModerationTopic): Promise<void> {
    this.busyId.set(topic.id);
    try {
      await this.moderation.approveTopicClose(topic.id);
      this.topics.update((list) => list.filter((t) => t.id !== topic.id));
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cerrar');
    } finally {
      this.busyId.set(null);
    }
  }

  async reject(topic: ModerationTopic): Promise<void> {
    this.busyId.set(topic.id);
    try {
      await this.moderation.rejectTopicClose(topic.id);
      this.topics.update((list) => list.filter((t) => t.id !== topic.id));
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo rechazar');
    } finally {
      this.busyId.set(null);
    }
  }
}
