import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  HermandadOfficialPost,
  HermandadPortalService,
  OfficialCategory,
  OFFICIAL_CATEGORIES,
} from '../../../core/hermandad/hermandad-portal.service';
import { HermandadPortalStore } from '../../../core/hermandad/hermandad-portal.store';
import { formatTimeAgo } from '../../../core/utils/date';

@Component({
  selector: 'app-hermandad-posts-page',
  standalone: true,
  imports: [RouterLink, FormsModule],
  templateUrl: './hermandad-posts.component.html',
  styleUrl: './hermandad-posts.component.scss',
})
export class HermandadPostsPageComponent implements OnInit {
  readonly store = inject(HermandadPortalStore);
  private readonly api = inject(HermandadPortalService);

  readonly timeAgo = formatTimeAgo;
  readonly categories = OFFICIAL_CATEGORIES;
  readonly categoryLabel = (v: string) => this.api.categoryLabel(v);
  readonly page = signal(0);
  readonly pageSize = 6;
  readonly categoryFilter = signal<'all' | OfficialCategory>('all');

  readonly categoryFilterOptions = [
    { value: 'all' as const, label: 'Todas' },
    ...OFFICIAL_CATEGORIES.map((c) => ({ value: c.value, label: c.label })),
  ];
  readonly cancellingId = signal<string | null>(null);
  readonly saving = signal(false);
  readonly dialogError = signal<string | null>(null);

  readonly previewPost = signal<HermandadOfficialPost | null>(null);
  readonly editingPost = signal<HermandadOfficialPost | null>(null);

  editTitle = '';
  editBody = '';
  editCategory: OfficialCategory = 'noticia';
  editImageFile: File | null = null;
  editImagePreview: string | null = null;
  editClearImage = false;

  readonly published = computed(() =>
    this.store.posts().filter((p) => !p.deletedAt),
  );

  readonly filteredPublished = computed(() => {
    const f = this.categoryFilter();
    const all = this.published();
    if (f === 'all') return all;
    return all.filter((p) => p.category === f);
  });

  readonly filteredScheduled = computed(() => {
    const f = this.categoryFilter();
    const all = this.store.scheduledPosts();
    if (f === 'all') return all;
    return all.filter((p) => p.category === f);
  });

  readonly pageCount = computed(() =>
    Math.max(1, Math.ceil(this.filteredPublished().length / this.pageSize)),
  );

  readonly visiblePosts = computed(() => {
    const list = this.filteredPublished();
    const p = Math.min(this.page(), this.pageCount() - 1);
    const start = p * this.pageSize;
    return list.slice(start, start + this.pageSize);
  });

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

  shiftPage(delta: number): void {
    const next = this.page() + delta;
    this.page.set(Math.max(0, Math.min(this.pageCount() - 1, next)));
  }

  setCategoryFilter(value: 'all' | OfficialCategory): void {
    this.categoryFilter.set(value);
    this.page.set(0);
  }

  formatSchedule(iso: string): string {
    return new Date(iso).toLocaleString('es-ES', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  postTitle(body: string): string {
    const bold = body.match(/^\*\*(.+?)\*\*/);
    if (bold?.[1]) return bold[1].trim();
    const line = body.split('\n').find((l) => l.trim());
    return (line ?? 'Publicación').trim().slice(0, 72);
  }

  postExcerpt(body: string): string {
    const withoutTitle = body.replace(/^\*\*(.+?)\*\*\s*/, '').trim();
    if (!withoutTitle) return '';
    return withoutTitle.length > 110
      ? `${withoutTitle.slice(0, 107)}…`
      : withoutTitle;
  }

  openPreview(post: HermandadOfficialPost): void {
    this.previewPost.set(post);
  }

  closePreview(): void {
    this.previewPost.set(null);
  }

  openEdit(post: HermandadOfficialPost): void {
    this.editingPost.set(post);
    this.editTitle = this.postTitle(post.body);
    this.editBody = post.body.replace(/^\*\*(.+?)\*\*\s*/, '').trim();
    this.editCategory = post.category;
    this.editImageFile = null;
    this.editClearImage = false;
    this.editImagePreview = post.imageUrl;
    this.dialogError.set(null);
  }

  closeEdit(): void {
    this.editingPost.set(null);
    this.clearEditImagePick();
  }

  onEditImagePicked(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      this.dialogError.set('La imagen no puede superar 5 MB.');
      return;
    }
    this.clearEditImagePick();
    this.editImageFile = file;
    this.editClearImage = false;
    this.editImagePreview = URL.createObjectURL(file);
    this.dialogError.set(null);
  }

  removeEditImage(): void {
    this.clearEditImagePick();
    this.editImageFile = null;
    this.editImagePreview = null;
    this.editClearImage = true;
  }

  private clearEditImagePick(): void {
    if (this.editImagePreview?.startsWith('blob:')) {
      URL.revokeObjectURL(this.editImagePreview);
    }
  }

  async saveEdit(): Promise<void> {
    const post = this.editingPost();
    if (!post) return;
    this.saving.set(true);
    this.dialogError.set(null);
    try {
      await this.store.updatePublishedPost({
        replyId: post.id,
        topicId: post.topicId,
        title: this.editTitle,
        body: this.editBody,
        category: this.editCategory,
        imageFile: this.editImageFile,
        clearImage: this.editClearImage,
        currentImageUrl: post.imageUrl,
      });
      this.closeEdit();
    } catch (err) {
      this.dialogError.set(
        err instanceof Error ? err.message : 'No se pudo guardar',
      );
    } finally {
      this.saving.set(false);
    }
  }

  async deletePublished(post: HermandadOfficialPost): Promise<void> {
    if (!confirm('¿Eliminar esta publicación del tablón?\nSi tenía evento en el calendario, también se quitará.')) return;
    try {
      await this.store.deletePublishedPost(post.id);
      if (this.previewPost()?.id === post.id) this.closePreview();
      if (this.editingPost()?.id === post.id) this.closeEdit();
    } catch (err) {
      alert(err instanceof Error ? err.message : 'No se pudo eliminar');
    }
  }

  async cancelScheduled(id: string): Promise<void> {
    this.cancellingId.set(id);
    try {
      await this.store.cancelScheduled(id);
    } finally {
      this.cancellingId.set(null);
    }
  }

  previewTitle(): string {
    const post = this.previewPost();
    return post ? this.postTitle(post.body) : '';
  }

  previewBody(): string {
    const post = this.previewPost();
    return post ? this.postExcerpt(post.body) || this.postTitle(post.body) : '';
  }
}
