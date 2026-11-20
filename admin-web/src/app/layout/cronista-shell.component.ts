import { Component, HostListener, inject, signal } from '@angular/core';
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

const NAV = [
  {
    id: 'home',
    label: 'Mis historias',
    route: '/cronista',
    exact: true,
    iconPath:
      'M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 19.5A2.5 2.5 0 0 0 6.5 22H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15Z',
  },
  {
    id: 'write',
    label: 'Escribir',
    route: '/cronista/escribir',
    exact: false,
    iconPath: 'M12 5v14M5 12h14',
  },
] as const;

@Component({
  selector: 'app-cronista-shell',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './cronista-shell.component.html',
  styleUrl: './hermandad-shell.component.scss',
})
export class CronistaShellComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly menuOpen = signal(false);
  readonly profile = this.auth.profile;
  readonly isAdmin = this.auth.isAdmin;
  readonly nav = NAV;

  constructor() {
    this.router.events
      .pipe(
        filter((e): e is NavigationEnd => e instanceof NavigationEnd),
        takeUntilDestroyed(),
      )
      .subscribe(() => this.closeMenu());
  }

  @HostListener('document:keydown.escape')
  onEscape(): void {
    if (this.menuOpen()) this.closeMenu();
  }

  closeMenu(): void {
    this.menuOpen.set(false);
    document.body.style.overflow = '';
  }

  toggleMenu(): void {
    this.menuOpen.update((v) => !v);
    document.body.style.overflow = this.menuOpen() ? 'hidden' : '';
  }

  async logout(): Promise<void> {
    this.closeMenu();
    await this.auth.signOut();
    await this.router.navigateByUrl('/login');
  }
}
