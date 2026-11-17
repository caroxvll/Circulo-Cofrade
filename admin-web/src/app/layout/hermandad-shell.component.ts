import {
  Component,
  HostListener,
  OnDestroy,
  OnInit,
  effect,
  inject,
  signal,
} from '@angular/core';
import {
  NavigationEnd,
  Router,
  RouterLink,
  RouterLinkActive,
  RouterOutlet,
} from '@angular/router';
import { filter } from 'rxjs';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { AuthService } from '../core/auth/auth.service';
import { HermandadPortalStore } from '../core/hermandad/hermandad-portal.store';
import { HermandadThemeService } from '../core/hermandad/hermandad-theme.service';
import { HERMANDAD_NAV } from '../core/nav/hermandad-modules';

@Component({
  selector: 'app-hermandad-shell',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './hermandad-shell.component.html',
  styleUrl: './hermandad-shell.component.scss',
})
export class HermandadShellComponent implements OnInit, OnDestroy {
  private readonly auth = inject(AuthService);
  private readonly store = inject(HermandadPortalStore);
  private readonly theme = inject(HermandadThemeService);
  private readonly router = inject(Router);

  readonly menuOpen = signal(false);
  readonly profile = this.auth.profile;
  readonly boards = this.store.boards;
  readonly refreshing = this.store.refreshing;
  readonly nav = HERMANDAD_NAV;
  readonly accent = this.theme.accent;
  readonly accentDark = this.theme.accentDark;

  constructor() {
    effect(() => {
      const p = this.profile();
      this.theme.loadForProfile(p?.id, p?.panelAccent);
    });

    this.router.events
      .pipe(
        filter((e): e is NavigationEnd => e instanceof NavigationEnd),
        takeUntilDestroyed(),
      )
      .subscribe(() => this.closeMenu());
  }

  ngOnInit(): void {
    void this.store.ensureLoaded();
  }

  ngOnDestroy(): void {
    document.body.style.overflow = '';
  }

  @HostListener('document:visibilitychange')
  onVisibilityChange(): void {
    if (document.visibilityState === 'visible') {
      this.store.revalidateIfStale();
    }
  }

  @HostListener('window:focus')
  onWindowFocus(): void {
    this.store.revalidateIfStale();
  }

  @HostListener('document:keydown.escape')
  onEscape(): void {
    if (this.menuOpen()) this.closeMenu();
  }

  closeMenu(): void {
    this.menuOpen.set(false);
    this.syncBodyScroll();
  }

  toggleMenu(): void {
    this.menuOpen.update((v) => !v);
    this.syncBodyScroll();
  }

  private syncBodyScroll(): void {
    document.body.style.overflow = this.menuOpen() ? 'hidden' : '';
  }

  async logout(): Promise<void> {
    this.closeMenu();
    await this.auth.signOut();
    await this.router.navigateByUrl('/login');
  }

  boardTitle(): string {
    return (
      this.store.primaryBoard()?.hermandadName ??
      this.profile()?.displayName ??
      'Tu hermandad'
    );
  }
}
