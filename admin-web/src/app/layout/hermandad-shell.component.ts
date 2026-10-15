import {
  Component,
  HostListener,
  OnInit,
  effect,
  inject,
  signal,
} from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
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
export class HermandadShellComponent implements OnInit {
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
  }

  ngOnInit(): void {
    void this.store.ensureLoaded();
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

  closeMenu(): void {
    this.menuOpen.set(false);
  }

  toggleMenu(): void {
    this.menuOpen.update((v) => !v);
  }

  async logout(): Promise<void> {
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
