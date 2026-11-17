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
import { ConfirmDialogService } from '../../../shared/confirm-dialog/confirm-dialog.service';

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
  private readonly confirmDialog = inject(ConfirmDialogService);

  readonly timeAgo = formatTimeAgo;
  readonly categories = OFFICIAL_CATEGORIES;
  readonly categoryLabel = (v: string) => this.api.categoryLabel(v);
  readonly page = signal(0);
  readonly deletedPage = signal(0);
  readonly pageSize = 20;
  readonly categoryFilter = signal<'all' | OfficialCategory>('all');
  readonly searchQuery = signal('');

  readonly categoryFilterOptions = [
    { value: 'all' as const, label: 'Todas' },
    ...OFFICIAL_CATEGORIES.map((c) => ({ value: c.value, label: c.label })),
  ];
  readonly cancellingId = signal<string | null>(null);
  readonly restoringId = signal<string | null>(null);
  readonly purgingId = signal<string | null>(null);
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
    const q = this.searchQuery().trim().toLowerCase();
    let list = this.published();
    if (f !== 'all') list = list.filter((p) => p.category === f);
    if (q) {
      list = list.filter((p) => {
        const title = this.postTitle(p.body).toLowerCase();
        const excerpt = this.postExcerpt(p.body).toLowerCase();
        const board = this.boardTitle(p.topicId).toLowerCase();
        return title.includes(q) || excerpt.includes(q) || board.includes(q);
      });
    }
    return list;
  });

  readonly filteredScheduled = computed(() => {
    const f = this.categoryFilter();
    const q = this.searchQuery().trim().toLowerCase();
    let list = this.store.scheduledPosts();
    if (f !== 'all') list = list.filter((p) => p.category === f);
    if (q) {
      list = list.filter((p) => {
        const title = this.postTitle(p.body).toLowerCase();
        const excerpt = this.postExcerpt(p.body).toLowerCase();
        const board = this.boardTitle(p.topicId).toLowerCase();
        return title.includes(q) || excerpt.includes(q) || board.includes(q);
      });
    }
    return list;
  });

  readonly filteredDeleted = computed(() => {
    const f = this.categoryFilter();
    const q = this.searchQuery().trim().toLowerCase();
    let list = this.store.deletedPosts();
    if (f !== 'all') list = list.filter((p) => p.category === f);
    if (q) {
      list = list.filter((p) => {
        const title = this.postTitle(p.body).toLowerCase();
        const excerpt = this.postExcerpt(p.body).toLowerCase();
        const board = this.boardTitle(p.topicId).toLowerCase();
        return title.includes(q) || excerpt.includes(q) || board.includes(q);
      });
    }
    return list;
  });

  readonly pageCount = computed(() =>
    Math.max(1, Math.ceil(this.filteredPublished().length / this.pageSize)),
  );

  readonly deletedPageCount = computed(() =>
    Math.max(1, Math.ceil(this.filteredDeleted().length / this.pageSize)),
  );

  readonly visiblePosts = computed(() => {
    const list = this.filteredPublished();
    const p = Math.min(this.page(), this.pageCount() - 1);
    const start = p * this.pageSize;
    return list.slice(start, start + this.pageSize);
  });

  readonly visibleDeleted = computed(() => {
    const list = this.filteredDeleted();
    const p = Math.min(this.deletedPage(), this.deletedPageCount() - 1);
    const start = p * this.pageSize;
    return list.slice(start, start + this.pageSize);
  });

  readonly rangeLabel = computed(() => {
    const total = this.filteredPublished().length;
    if (total === 0) return '0';
    const p = Math.min(this.page(), this.pageCount() - 1);
    const start = p * this.pageSize + 1;
    const end = Math.min(total, start + this.pageSize - 1);
    return `${start}–${end} de ${total}`;
  });

  readonly deletedRangeLabel = computed(() => {
    const total = this.filteredDeleted().length;
    if (total === 0) return '0';
    const p = Math.min(this.deletedPage(), this.deletedPageCount() - 1);
    const start = p * this.pageSize + 1;
    const end = Math.min(total, start + this.pageSize - 1);
    return `${start}–${end} de ${total}`;
  });

  ngOnInit(): void {
    void this.store.ensureLoaded();
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

  shiftDeletedPage(delta: number): void {
    const next = this.deletedPage() + delta;
    this.deletedPage.set(
      Math.max(0, Math.min(this.deletedPageCount() - 1, next)),
    );
  }

  setCategoryFilter(value: 'all' | OfficialCategory): void {
    this.categoryFilter.set(value);
    this.page.set(0);
    this.deletedPage.set(0);
  }

  onSearchInput(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.searchQuery.set(value);
    this.page.set(0);
    this.deletedPage.set(0);
  }

  clearSearch(): void {
    this.searchQuery.set('');
    this.page.set(0);
    this.deletedPage.set(0);
  }

  formatPublishedAt(iso: string): string {
    return new Date(iso).toLocaleString('es-ES', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
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
    const ok = await this.confirmDialog.confirm({
      title: 'Eliminar publicación',
      message:
        'Se quitará del tablón y pasará a Eliminadas.\nSi tenía evento en el calendario, también se quitará.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      tone: 'danger',
    });
    if (!ok) return;
    try {
      await this.store.deletePublishedPost(post.id);
      if (this.previewPost()?.id === post.id) this.closePreview();
      if (this.editingPost()?.id === post.id) this.closeEdit();
    } catch (err) {
      await this.confirmDialog.alert({
        title: 'No se pudo eliminar',
        message: err instanceof Error ? err.message : 'Inténtalo de nuevo.',
      });
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

  async restoreDeleted(id: string): Promise<void> {
    const ok = await this.confirmDialog.confirm({
      title: 'Restaurar publicación',
      message:
        'Volverá a verse en el tablón y en la app.\nEl evento de calendario (si lo tenía) no se recrea solo.',
      confirmLabel: 'Restaurar',
      cancelLabel: 'Cancelar',
      tone: 'primary',
    });
    if (!ok) return;
    this.restoringId.set(id);
    try {
      await this.store.restorePublishedPost(id);
    } catch (err) {
      await this.confirmDialog.alert({
        title: 'No se pudo restaurar',
        message:
          err instanceof Error
            ? err.message
            : 'Comprueba que ejecutaste restore_forum_reply.sql en Supabase.',
      });
    } finally {
      this.restoringId.set(null);
    }
  }

  async purgeDeleted(id: string): Promise<void> {
    const ok = await this.confirmDialog.confirm({
      title: 'Borrar definitivamente',
      message:
        'Se eliminará para siempre del historial.\nEsta acción no se puede deshacer.',
      confirmLabel: 'Borrar para siempre',
      cancelLabel: 'Cancelar',
      tone: 'danger',
    });
    if (!ok) return;
    this.purgingId.set(id);
    try {
      await this.store.hardDeletePublishedPost(id);
      if (this.deletedPage() >= this.deletedPageCount()) {
        this.deletedPage.set(Math.max(0, this.deletedPageCount() - 1));
      }
    } catch (err) {
      await this.confirmDialog.alert({
        title: 'No se pudo borrar',
        message:
          err instanceof Error
            ? err.message
            : 'Comprueba que ejecutaste hard_delete_forum_reply.sql en Supabase.',
      });
    } finally {
      this.purgingId.set(null);
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
