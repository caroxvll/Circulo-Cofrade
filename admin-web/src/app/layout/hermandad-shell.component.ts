import { Component, OnInit, inject, signal } from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from '../core/auth/auth.service';
import { HermandadPortalStore } from '../core/hermandad/hermandad-portal.store';
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
  private readonly router = inject(Router);

  readonly menuOpen = signal(false);
  readonly profile = this.auth.profile;
  readonly boards = this.store.boards;
  readonly nav = HERMANDAD_NAV;

  ngOnInit(): void {
    void this.store.reload();
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
    return this.store.primaryBoard()?.hermandadName
      ?? this.profile()?.displayName
      ?? 'Tu hermandad';
  }
}
