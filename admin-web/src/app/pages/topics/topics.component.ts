import { Component, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ModerationService } from '../../core/moderation/moderation.service';
import { ModerationTopic, REJECTION_PRESETS } from '../../core/moderation/moderation.models';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-topics-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './topics.component.html',
})
export class TopicsPageComponent implements OnInit {
  private readonly moderation = inject(ModerationService);

  readonly topics = signal<ModerationTopic[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly rejectTarget = signal<ModerationTopic | null>(null);
  rejectReason = '';
  readonly presets = REJECTION_PRESETS;
  readonly timeAgo = formatTimeAgo;

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.topics.set(await this.moderation.fetchPendingTopics());
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  openReject(topic: ModerationTopic): void {
    this.rejectTarget.set(topic);
    this.rejectReason = '';
  }

  closeReject(): void {
    this.rejectTarget.set(null);
    this.rejectReason = '';
  }

  usePreset(preset: string): void {
    this.rejectReason = preset;
  }

  async approve(topic: ModerationTopic): Promise<void> {
    this.busyId.set(topic.id);
    this.error.set(null);
    try {
      await this.moderation.approveTopic(topic.id);
      this.topics.update((list) => list.filter((t) => t.id !== topic.id));
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo aprobar');
    } finally {
      this.busyId.set(null);
    }
  }

  async confirmReject(): Promise<void> {
    const topic = this.rejectTarget();
    if (!topic) return;
    this.busyId.set(topic.id);
    this.error.set(null);
    try {
      await this.moderation.rejectTopic(topic.id, this.rejectReason);
      this.topics.update((list) => list.filter((t) => t.id !== topic.id));
      this.closeReject();
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo rechazar');
    } finally {
      this.busyId.set(null);
    }
  }
}
