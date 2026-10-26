import { Component, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ModerationService } from '../../core/moderation/moderation.service';
import { ModerationTopic, REJECTION_PRESETS } from '../../core/moderation/moderation.models';
import {
  TopicPollView,
  TopicPollsService,
} from '../../core/forums/topic-polls.service';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-topics-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './topics.component.html',
})
export class TopicsPageComponent implements OnInit {
  private readonly moderation = inject(ModerationService);
  private readonly pollsApi = inject(TopicPollsService);

  readonly topics = signal<ModerationTopic[]>([]);
  readonly pollsByTopic = signal<Map<string, TopicPollView>>(new Map());
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

  pollFor(topicId: string): TopicPollView | undefined {
    return this.pollsByTopic().get(topicId);
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const topics = await this.moderation.fetchPendingTopics();
      this.topics.set(topics);
      const polls = await this.pollsApi.fetchPollsByTopicIds(topics.map((t) => t.id));
      this.pollsByTopic.set(polls);
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
      this.pollsByTopic.update((map) => {
        const next = new Map(map);
        next.delete(topic.id);
        return next;
      });
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
      this.pollsByTopic.update((map) => {
        const next = new Map(map);
        next.delete(topic.id);
        return next;
      });
      this.closeReject();
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo rechazar');
    } finally {
      this.busyId.set(null);
    }
  }

  async closePoll(topic: ModerationTopic): Promise<void> {
    const poll = this.pollFor(topic.id);
    if (!poll || poll.closedAt) return;
    if (!confirm('¿Cerrar esta encuesta? Ya no se podrán emitir más votos.')) return;

    this.busyId.set(`poll-${poll.id}`);
    this.error.set(null);
    try {
      await this.pollsApi.closePoll(poll.id);
      this.pollsByTopic.update((map) => {
        const next = new Map(map);
        next.set(topic.id, { ...poll, closedAt: new Date().toISOString() });
        return next;
      });
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cerrar la encuesta');
    } finally {
      this.busyId.set(null);
    }
  }

  async deletePoll(topic: ModerationTopic): Promise<void> {
    const poll = this.pollFor(topic.id);
    if (!poll) return;
    if (!confirm('¿Eliminar la encuesta de este tema? Se borrarán también los votos.')) return;

    this.busyId.set(`poll-${poll.id}`);
    this.error.set(null);
    try {
      await this.pollsApi.deletePoll(poll.id);
      this.pollsByTopic.update((map) => {
        const next = new Map(map);
        next.delete(topic.id);
        return next;
      });
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar la encuesta');
    } finally {
      this.busyId.set(null);
    }
  }
}
