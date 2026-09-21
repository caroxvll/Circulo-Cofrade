import { Component, OnInit, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { HermandadPortalService } from '../../../core/hermandad/hermandad-portal.service';
import { HermandadPortalStore } from '../../../core/hermandad/hermandad-portal.store';
import { formatTimeAgo } from '../../../core/utils/date';

@Component({
  selector: 'app-hermandad-posts-page',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './hermandad-posts.component.html',
  styleUrl: '../hermandad-portal-shared.scss',
})
export class HermandadPostsPageComponent implements OnInit {
  readonly store = inject(HermandadPortalStore);
  private readonly api = inject(HermandadPortalService);

  readonly timeAgo = formatTimeAgo;
  readonly categoryLabel = (v: string) => this.api.categoryLabel(v);

  ngOnInit(): void {
    if (!this.store.boards().length && !this.store.loading()) {
      void this.store.reload();
    }
  }

  boardTitle(topicId: string): string {
    return (
      this.store.boards().find((b) => b.topicId === topicId)?.title ?? topicId
    );
  }

  visiblePosts() {
    return this.store.posts().filter((p) => !p.deletedAt);
  }
}
