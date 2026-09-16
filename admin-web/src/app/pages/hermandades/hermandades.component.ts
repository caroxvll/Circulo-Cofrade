import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  AdminUserRow,
  CommunityService,
  CreatedHermandadAccount,
  HandleHit,
  HermandadAssignment,
  HermandadTopicOption,
} from '../../core/community/community.service';
import { HandleSearchComponent } from '../../shared/handle-search.component';
import { formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-hermandades-page',
  standalone: true,
  imports: [FormsModule, HandleSearchComponent],
  templateUrl: './hermandades.component.html',
})
export class HermandadesPageComponent implements OnInit {
  private readonly community = inject(CommunityService);

  readonly assignments = signal<HermandadAssignment[]>([]);
  readonly topics = signal<HermandadTopicOption[]>([]);
  readonly brotherhoods = signal<AdminUserRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly creating = signal(false);
  readonly linking = signal(false);
  readonly busyKey = signal<string | null>(null);
  readonly created = signal<CreatedHermandadAccount | null>(null);

  displayName = '';
  handle = '';
  email = '';
  password = '';
  autoPassword = true;
  createTopicId = '';
  linkTopicId = '';
  selected: HandleHit | null = null;
  readonly timeAgo = formatTimeAgo;

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [assignments, topics, brotherhoods] = await Promise.all([
        this.community.fetchHermandadAssignments(),
        this.community.fetchHermandadBoardTopics(),
        this.community.fetchBrotherhoodAccounts(),
      ]);
      this.assignments.set(assignments);
      this.topics.set(topics);
      this.brotherhoods.set(brotherhoods);
      if (!this.createTopicId && topics.length) this.createTopicId = '';
      if (!this.linkTopicId && topics.length) this.linkTopicId = topics[0].id;
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async createAccount(): Promise<void> {
    this.creating.set(true);
    this.error.set(null);
    this.created.set(null);
    try {
      const result = await this.community.createHermandadAccount({
        email: this.email,
        handle: this.handle,
        displayName: this.displayName,
        password: this.autoPassword ? null : this.password,
        topicId: this.createTopicId || null,
      });
      this.created.set(result);
      this.displayName = '';
      this.handle = '';
      this.email = '';
      this.password = '';
      await this.reload();
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? err.message
          : 'No se pudo crear la cuenta (¿Edge Function desplegada?)',
      );
    } finally {
      this.creating.set(false);
    }
  }

  async linkAccount(): Promise<void> {
    if (!this.selected || !this.linkTopicId) {
      this.error.set('Elige cuenta y tablón.');
      return;
    }
    this.linking.set(true);
    this.error.set(null);
    try {
      await this.community.assignHermandadTopic(
        this.selected.id,
        this.linkTopicId,
      );
      this.selected = null;
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo vincular');
    } finally {
      this.linking.set(false);
    }
  }

  async remove(row: HermandadAssignment): Promise<void> {
    if (!confirm(`¿Quitar a @${row.handle} de «${row.topicTitle}»?`)) return;
    const key = `${row.profileId}:${row.topicId}`;
    this.busyKey.set(key);
    try {
      await this.community.removeHermandadAssignment(
        row.profileId,
        row.topicId,
      );
      this.assignments.update((list) =>
        list.filter(
          (a) => !(a.profileId === row.profileId && a.topicId === row.topicId),
        ),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo quitar');
    } finally {
      this.busyKey.set(null);
    }
  }

  async copyPassword(): Promise<void> {
    const pwd = this.created()?.temporaryPassword;
    if (!pwd) return;
    await navigator.clipboard.writeText(pwd);
  }
}
