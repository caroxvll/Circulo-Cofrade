import { Component, inject, OnInit, signal } from '@angular/core';
import { ModerationService } from '../../core/moderation/moderation.service';
import { ModerationTopic } from '../../core/moderation/moderation.models';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-rejected-topics-page',
  standalone: true,
  templateUrl: './rejected-topics.component.html',
})
export class RejectedTopicsPageComponent implements OnInit {
  private readonly moderation = inject(ModerationService);

  readonly topics = signal<ModerationTopic[]>([]);
  readonly loading = signal(true);
  readonly loadingMore = signal(false);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly hasMore = signal(true);
  readonly timeAgo = formatTimeAgo;
  private offset = 0;
  private readonly pageSize = 20;

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    this.offset = 0;
    try {
      const rows = await this.moderation.fetchRejectedTopics(0, this.pageSize);
      this.topics.set(rows);
      this.hasMore.set(rows.length === this.pageSize);
      this.offset = rows.length;
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async loadMore(): Promise<void> {
    this.loadingMore.set(true);
    try {
      const rows = await this.moderation.fetchRejectedTopics(
        this.offset,
        this.pageSize,
      );
      this.topics.update((list) => [...list, ...rows]);
      this.offset += rows.length;
      this.hasMore.set(rows.length === this.pageSize);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar más');
    } finally {
      this.loadingMore.set(false);
    }
  }

  async remove(topic: ModerationTopic): Promise<void> {
    if (!confirm(`¿Eliminar definitivamente «${topic.title}»?`)) return;
    this.busyId.set(topic.id);
    try {
      await this.moderation.deleteTopic(topic.id);
      this.topics.update((list) => list.filter((t) => t.id !== topic.id));
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar');
    } finally {
      this.busyId.set(null);
    }
  }
}
