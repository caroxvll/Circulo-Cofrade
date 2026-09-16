import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { AuthService } from '../core/auth/auth.service';
import { ModerationService } from '../core/moderation/moderation.service';
import {
  JuntaModuleId,
  JUNTA_SECTION_TITLES,
  JuntaNavSection,
  visibleModules,
} from '../core/nav/junta-modules';

const NAV_ICON_PATHS: Record<JuntaModuleId, string> = {
  overview:
    'M4 11.5 12 4l8 7.5V20a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1v-8.5Z',
  topics:
    'M7 4h10a2 2 0 0 1 2 2v14l-4-2.5L11 20l-4-2.5L3 20V6a2 2 0 0 1 2-2h2Zm1 5h8M8 12h8M8 15h5',
  'rejected-topics':
    'M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18Zm3.2 5.8-6.4 6.4m0-6.4 6.4 6.4',
  reports:
    'M12 3v3m0 12v3M4.9 4.9l2.1 2.1m10 10 2.1 2.1M3 12h3m12 0h3M4.9 19.1l2.1-2.1m10-10 2.1-2.1M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8Z',
  events:
    'M7 4v2m10-2v2M5 9h14M6 6h12a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Zm3 7h.01M12 13h.01M15 13h.01M9 16h.01M12 16h.01M15 16h.01',
  'close-requests':
    'M8 6h11l-1.5 9.5a2 2 0 0 1-2 1.7H10a2 2 0 0 1-2-1.5L6.2 4H3m5 15a1.2 1.2 0 1 0 0-2.4A1.2 1.2 0 0 0 8 21Zm9 0a1.2 1.2 0 1 0 0-2.4 1.2 1.2 0 0 0 0 2.4Z',
  conversations:
    'M5 5h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H12l-4 3v-3H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Zm3 4h8M8 12h5',
  news:
    'M5 4h11a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2V4Zm3 4h8M8 12h8M8 16h5M18 8h1a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-1',
  users:
    'M16 19v-1.2A3.8 3.8 0 0 0 12.2 14H7.8A3.8 3.8 0 0 0 4 17.8V19m12.5-9.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm5.5 9.5v-.8A3.2 3.2 0 0 0 18 15.5h-.4m1.9-6a2.5 2.5 0 1 1-3.4 3.5',
  moderators:
    'M12 3 4.5 6.2v4.6C4.5 15.8 7.7 19.7 12 21c4.3-1.3 7.5-5.2 7.5-10.2V6.2L12 3Zm0 6v4m0 3h.01',
  hermandades:
    'M4 20h16M6 20V9l6-4 6 4v11M10 20v-5h4v5',
  forums:
    'M8 6h13v10H8zm0 0H5a2 2 0 0 0-2 2v8l3-2h2m3-8v2m0 3h.01',
  season:
    'M12 3v2m0 14v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M3 12h2m14 0h2M4.9 19.1l1.4-1.4m11.4-11.4 1.4-1.4M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8Z',
  ads:
    'M4 9h3l5-4v14l-5-4H4V9Zm13.5 1.5a4.5 4.5 0 0 1 0 5M16 8a7 7 0 0 1 0 10',
  companies:
    'M4 20h16M6 20V6a1 1 0 0 1 1-1h5v15M12 9h6a1 1 0 0 1 1 1v10M9 9h.01M9 12h.01M9 15h.01M15 12h.01M15 15h.01',
  finance:
    'M12 3v18m4-14H9.5a2.5 2.5 0 0 0 0 5H14a2.5 2.5 0 0 1 0 5H7',
  quiz:
    'M9 9a3 3 0 1 1 5.2 2.1C13.5 12 12 12.7 12 14v1m0 3h.01M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18Z',
  notifications:
    'M6 16h12l-1.2-2.1a5.8 5.8 0 0 1-.8-3V9a5 5 0 0 0-10 0v1.9c0 1.1-.3 2.1-.8 3L6 16Zm4.2 2a2 2 0 0 0 3.6 0',
  'demo-world':
    'M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18Zm0 0c2.5 2.8 4 6.2 4 9s-1.5 6.2-4 9m0-18c-2.5 2.8-4 6.2-4 9s1.5 6.2 4 9M3.5 9.5h17m-17 5h17',
};

@Component({
  selector: 'app-shell',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './shell.component.html',
  styleUrl: './shell.component.scss',
})
export class ShellComponent implements OnInit {
  private static readonly collapseKey = 'junta.sidebar.collapsed';

  private readonly auth = inject(AuthService);
  private readonly moderation = inject(ModerationService);
  private readonly router = inject(Router);
  private readonly sanitizer = inject(DomSanitizer);

  readonly menuOpen = signal(false);
  readonly sidebarCollapsed = signal(this.readCollapsed());
  readonly profile = this.auth.profile;
  readonly isAdmin = this.auth.isAdmin;
  readonly counts = this.moderation.counts;

  private readonly iconCache = new Map<JuntaModuleId, SafeHtml>();

  readonly modules = computed(() => visibleModules(this.isAdmin()));

  readonly overview = computed(
    () => this.modules().find((m) => m.id === 'overview')!,
  );

  readonly sections = computed(() => {
    const order: JuntaNavSection[] = ['moderation', 'community', 'platform'];
    const mods = this.modules().filter((m) => m.section);
    return order
      .map((section) => ({
        section,
        title: JUNTA_SECTION_TITLES[section],
        items: mods.filter((m) => m.section === section),
      }))
      .filter((group) => group.items.length > 0);
  });

  constructor() {
    this.router.events
      .pipe(
        filter((e): e is NavigationEnd => e instanceof NavigationEnd),
        takeUntilDestroyed(),
      )
      .subscribe(() => this.closeMenu());
  }

  ngOnInit(): void {
    void this.moderation.refreshCounts();
  }

  badgeFor(moduleId: JuntaModuleId): number {
    const c = this.counts();
    switch (moduleId) {
      case 'topics':
        return c.topics;
      case 'reports':
        return c.reports;
      case 'events':
        return c.events;
      case 'close-requests':
        return c.closeRequests;
      default:
        return 0;
    }
  }

  /** Si hay solicitudes de evento, el menú abre la cola directamente. */
  navQueryParams(moduleId: JuntaModuleId): Record<string, string> | null {
    if (moduleId === 'events' && this.badgeFor('events') > 0) {
      return { tab: 'pending' };
    }
    return null;
  }

  navIcon(id: JuntaModuleId): SafeHtml {
    const cached = this.iconCache.get(id);
    if (cached) return cached;
    const d = NAV_ICON_PATHS[id] ?? NAV_ICON_PATHS.overview;
    const html = `<svg viewBox="0 0 24 24" focusable="false"><path d="${d}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
    const safe = this.sanitizer.bypassSecurityTrustHtml(html);
    this.iconCache.set(id, safe);
    return safe;
  }

  toggleMenu(): void {
    this.menuOpen.update((open) => !open);
    this.syncBodyScroll();
  }

  closeMenu(): void {
    this.menuOpen.set(false);
    this.syncBodyScroll();
  }

  toggleSidebarCollapse(): void {
    const next = !this.sidebarCollapsed();
    this.sidebarCollapsed.set(next);
    try {
      localStorage.setItem(ShellComponent.collapseKey, next ? '1' : '0');
    } catch {
      /* ignore quota / private mode */
    }
  }

  private readCollapsed(): boolean {
    try {
      return localStorage.getItem(ShellComponent.collapseKey) === '1';
    } catch {
      return false;
    }
  }

  private syncBodyScroll(): void {
    document.body.style.overflow = this.menuOpen() ? 'hidden' : '';
  }

  async signOut(): Promise<void> {
    this.closeMenu();
    await this.auth.signOut();
    location.href = '/login';
  }
}
