import { Component, OnInit, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import { HermandadPortalStore } from '../../../core/hermandad/hermandad-portal.store';
import { HermandadPortalService } from '../../../core/hermandad/hermandad-portal.service';
import { formatTimeAgo } from '../../../core/utils/date';

@Component({
  selector: 'app-hermandad-home-page',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './hermandad-home.component.html',
  styleUrl: '../hermandad-portal-shared.scss',
})
export class HermandadHomePageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  readonly store = inject(HermandadPortalStore);
  private readonly api = inject(HermandadPortalService);

  readonly profile = this.auth.profile;
  readonly timeAgo = formatTimeAgo;
  readonly categoryLabel = (v: string) => this.api.categoryLabel(v);

  ngOnInit(): void {
    if (!this.store.boards().length && !this.store.loading()) {
      void this.store.reload();
    }
  }

  recentPosts() {
    return this.store.posts().filter((p) => !p.deletedAt).slice(0, 5);
  }
}
