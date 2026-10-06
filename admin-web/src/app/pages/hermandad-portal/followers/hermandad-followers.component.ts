import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { HermandadPortalService } from '../../../core/hermandad/hermandad-portal.service';
import { HermandadPortalStore } from '../../../core/hermandad/hermandad-portal.store';

@Component({
  selector: 'app-hermandad-followers-page',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './hermandad-followers.component.html',
  styleUrl: './hermandad-followers.component.scss',
})
export class HermandadFollowersPageComponent implements OnInit {
  readonly store = inject(HermandadPortalStore);
  private readonly api = inject(HermandadPortalService);

  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly rows = signal<
    Awaited<ReturnType<HermandadPortalService['fetchTopicFollowers']>>
  >([]);
  readonly pageIndex = signal(0);
  readonly pageSize = 50;

  readonly displayName = computed(
    () =>
      this.store.primaryBoard()?.hermandadName ??
      this.store.boards()[0]?.hermandadName ??
      'Tu tablón',
  );

  readonly total = computed(() => this.store.followerCount());

  readonly topicId = computed(() => this.store.activeTopicId());

  readonly pageCount = computed(() =>
    Math.max(1, Math.ceil(this.total() / this.pageSize)),
  );

  readonly rangeLabel = computed(() => {
    const total = this.total();
    if (total <= 0) return '';
    const page = Math.min(this.pageIndex(), this.pageCount() - 1);
    const from = page * this.pageSize + 1;
    const to = Math.min(total, (page + 1) * this.pageSize);
    return `${from}–${to} de ${total.toLocaleString('es-ES')}`;
  });

  ngOnInit(): void {
    if (!this.store.boards().length && !this.store.loading()) {
      void this.store.reload().then(() => this.loadPage(0));
    } else {
      void this.loadPage(0);
    }
  }

  async loadPage(page: number): Promise<void> {
    const topicId = this.topicId();
    if (!topicId) return;

    const maxPage = this.pageCount() - 1;
    const safePage = Math.max(0, Math.min(maxPage, page));
    this.pageIndex.set(safePage);

    this.loading.set(true);
    this.error.set(null);
    try {
      const list = await this.api.fetchTopicFollowers(
        topicId,
        this.pageSize,
        safePage * this.pageSize,
      );
      this.rows.set(list);
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? err.message
          : 'No se pudo cargar la lista de seguidores. ¿Has aplicado la migración SQL?',
      );
      this.rows.set([]);
    } finally {
      this.loading.set(false);
    }
  }

  shiftPage(delta: number): void {
    void this.loadPage(this.pageIndex() + delta);
  }

  formatFollowedAt(iso: string): string {
    if (!iso) return '';
    return new Date(iso).toLocaleDateString('es-ES', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });
  }

  handleLabel(handle: string): string {
    const h = handle.trim();
    return h.startsWith('@') ? h : `@${h}`;
  }
}
