import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { HermandadPortalStore } from '../../../core/hermandad/hermandad-portal.store';
import {
  HermandadPortalService,
  OFFICIAL_CATEGORIES,
  OfficialCategory,
} from '../../../core/hermandad/hermandad-portal.service';
import {
  CALENDAR_EVENT_TYPES,
  eventTypeLabel,
} from '../../../core/events/events.models';
import { formatTimeAgo } from '../../../core/utils/date';

export type EventFilterValue = 'all' | (typeof CALENDAR_EVENT_TYPES)[number]['value'];
export type PostCategoryFilter = 'all' | OfficialCategory;

@Component({
  selector: 'app-hermandad-home-page',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './hermandad-home.component.html',
  styleUrl: './hermandad-home.component.scss',
})
export class HermandadHomePageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  readonly store = inject(HermandadPortalStore);
  private readonly api = inject(HermandadPortalService);

  readonly profile = this.auth.profile;
  readonly timeAgo = formatTimeAgo;
  readonly categoryLabel = (v: string) => this.api.categoryLabel(v);

  readonly eventsPage = signal(0);
  readonly eventsPerPage = 2;
  readonly eventFilter = signal<EventFilterValue>('all');
  readonly postCategoryFilter = signal<PostCategoryFilter>('all');

  readonly eventTypeOptions = [
    { value: 'all' as const, label: 'Todos' },
    ...CALENDAR_EVENT_TYPES.map((t) => ({
      value: t.value,
      label: t.cellLabel,
    })),
  ];

  readonly postCategoryOptions = [
    { value: 'all' as const, label: 'Todas' },
    ...OFFICIAL_CATEGORIES.map((c) => ({
      value: c.value,
      label: c.label,
    })),
  ];

  readonly eventTypeLabel = eventTypeLabel;

  readonly greeting = computed(() => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  });

  readonly board = computed(() => this.store.primaryBoard());

  readonly displayName = computed(
    () =>
      this.board()?.hermandadName ||
      this.profile()?.displayName ||
      'hermandad',
  );

  readonly postsThisYear = computed(() => {
    const year = new Date().getFullYear();
    return this.store
      .posts()
      .filter((p) => !p.deletedAt && new Date(p.createdAt).getFullYear() === year)
      .length;
  });

  readonly recentPosts = computed(() =>
    this.store.posts().filter((p) => !p.deletedAt),
  );

  readonly filteredUpcomingEvents = computed(() => {
    const f = this.eventFilter();
    const all = this.store.upcomingEvents();
    if (f === 'all') return all;
    return all.filter((e) => e.eventType === f);
  });

  readonly filteredRecentPosts = computed(() => {
    const f = this.postCategoryFilter();
    const all = this.recentPosts();
    if (f === 'all') return all;
    return all.filter((p) => p.category === f);
  });

  readonly eventsPageCount = computed(() =>
    Math.max(
      1,
      Math.ceil(this.filteredUpcomingEvents().length / this.eventsPerPage),
    ),
  );

  readonly visibleEvents = computed(() => {
    const list = this.filteredUpcomingEvents();
    const page = Math.min(this.eventsPage(), this.eventsPageCount() - 1);
    const start = page * this.eventsPerPage;
    return list.slice(start, start + this.eventsPerPage);
  });

  /** Más reciente (ya ordenada en store). */
  readonly featuredPost = computed(() => this.filteredRecentPosts()[0] ?? null);

  readonly olderPosts = computed(() => this.filteredRecentPosts().slice(1));

  ngOnInit(): void {
    if (!this.store.boards().length && !this.store.loading()) {
      void this.store.reload();
    }
  }

  shiftEvents(delta: number): void {
    const next = this.eventsPage() + delta;
    const max = this.eventsPageCount() - 1;
    this.eventsPage.set(Math.max(0, Math.min(max, next)));
  }

  setEventFilter(value: EventFilterValue): void {
    this.eventFilter.set(value);
    this.eventsPage.set(0);
  }

  setPostCategoryFilter(value: PostCategoryFilter): void {
    this.postCategoryFilter.set(value);
  }

  async deleteEvent(eventId: string, title: string): Promise<void> {
    const ok = window.confirm(
      `¿Quitar «${title}» del calendario?\nDejará de verse en la app.`,
    );
    if (!ok) return;
    try {
      await this.store.deleteUpcomingEvent(eventId);
    } catch (err) {
      console.error(err);
      window.alert('No se pudo quitar el evento. Inténtalo de nuevo.');
    }
  }

  postTitle(body: string): string {
    const bold = body.match(/^\*\*(.+?)\*\*/);
    if (bold?.[1]) return bold[1].trim();
    const line = body.split('\n').find((l) => l.trim());
    return (line ?? 'Publicación').trim().slice(0, 80);
  }

  postExcerpt(body: string): string {
    const withoutTitle = body.replace(/^\*\*(.+?)\*\*\s*/, '').trim();
    if (!withoutTitle) return 'Sin extracto.';
    return withoutTitle.length > 90
      ? `${withoutTitle.slice(0, 87)}…`
      : withoutTitle;
  }

  formatEventDay(iso: string): { day: string; month: string } {
    const d = new Date(iso);
    const day = String(d.getDate()).padStart(2, '0');
    const month = d
      .toLocaleDateString('es-ES', { month: 'short' })
      .replace('.', '')
      .toUpperCase();
    return { day, month };
  }

  formatEventTime(iso: string): string {
    return new Date(iso).toLocaleTimeString('es-ES', {
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  formatCount(n: number): string {
    if (n >= 1000) {
      const k = n / 1000;
      return `${k.toFixed(k >= 10 ? 0 : 1).replace('.', ',')}k`;
    }
    return String(n);
  }
}
