import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { FormsModule } from '@angular/forms';
import {
  NOTICIAS_RELATED_OPTIONS,
  NewsTopic,
  ScheduledNews,
} from '../../core/news/news.models';
import { NewsService } from '../../core/news/news.service';
import { formatDateTime } from '../../core/utils/date';
import {
  MdWrapKind,
  forumMarkdownToSafeHtml,
  wrapMarkdownSelection,
} from '../../shared/forum-markdown';

type NewsTab = 'compose' | 'published' | 'scheduled';

@Component({
  selector: 'app-news-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './news.component.html',
  styleUrl: './news.component.scss',
})
export class NewsPageComponent implements OnInit {
  private readonly api = inject(NewsService);
  private readonly sanitizer = inject(DomSanitizer);

  readonly tab = signal<NewsTab>('compose');
  readonly published = signal<NewsTopic[]>([]);
  readonly scheduled = signal<ScheduledNews[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly uploading = signal(false);
  readonly error = signal<string | null>(null);
  readonly ok = signal<string | null>(null);
  readonly showPreview = signal(true);
  /** Fuerza recálculo de la vista previa al editar. */
  readonly previewTick = signal(0);

  readonly relatedOptions = NOTICIAS_RELATED_OPTIONS;
  readonly dateTime = formatDateTime;
  readonly canManage = computed(() => this.api.canManageNoticias());

  readonly previewHtml = computed<SafeHtml>(() => {
    this.previewTick();
    return this.sanitizer.bypassSecurityTrustHtml(
      forumMarkdownToSafeHtml(this.body),
    );
  });

  readonly previewRelated = computed(() => {
    this.previewTick();
    return this.api.relatedLabel(this.relatedForumId || null);
  });

  title = '';
  body = '';
  relatedForumId = '';
  coverImageUrl = '';
  scheduleMode = false;
  scheduledLocal = '';
  /** Si edita una publicada. */
  editingTopicId: string | null = null;
  /** Si edita una programada. */
  editingScheduledId: string | null = null;

  ngOnInit(): void {
    void this.reload();
  }

  isEditing(): boolean {
    return !!(this.editingTopicId || this.editingScheduledId);
  }

  setTab(tab: NewsTab): void {
    this.tab.set(tab);
    this.error.set(null);
    this.ok.set(null);
  }

  onBodyInput(): void {
    this.previewTick.update((n) => n + 1);
  }

  onTitleInput(): void {
    this.previewTick.update((n) => n + 1);
  }

  onMetaChange(): void {
    this.previewTick.update((n) => n + 1);
  }

  applyFormat(kind: MdWrapKind, textarea: HTMLTextAreaElement): void {
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const next = wrapMarkdownSelection(this.body, start, end, kind);
    this.body = next.text;
    this.previewTick.update((n) => n + 1);
    queueMicrotask(() => {
      textarea.focus();
      textarea.setSelectionRange(next.selectionStart, next.selectionEnd);
    });
  }

  togglePreview(): void {
    this.showPreview.update((v) => !v);
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [published, scheduled] = await Promise.all([
        this.api.listPublished(),
        this.api.listScheduled(),
      ]);
      this.published.set(published);
      this.scheduled.set(scheduled);
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudieron cargar las noticias'));
    } finally {
      this.loading.set(false);
    }
  }

  async onCoverSelected(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    this.uploading.set(true);
    this.error.set(null);
    try {
      this.coverImageUrl = await this.api.uploadCover(file);
      this.previewTick.update((n) => n + 1);
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo subir la portada'));
    } finally {
      this.uploading.set(false);
      input.value = '';
    }
  }

  clearCover(): void {
    this.coverImageUrl = '';
    this.previewTick.update((n) => n + 1);
  }

  async submit(): Promise<void> {
    if (!this.canManage()) return;
    this.busy.set(true);
    this.error.set(null);
    this.ok.set(null);
    try {
      const payload = {
        title: this.title,
        body: this.body,
        relatedForumId: this.relatedForumId || null,
        coverImageUrl: this.coverImageUrl || null,
        scheduledAt: this.scheduleMode
          ? this.toIsoFromLocal(this.scheduledLocal)
          : null,
      };

      if (this.editingTopicId) {
        await this.api.updatePublished(this.editingTopicId, payload);
        this.ok.set('Noticia actualizada.');
        this.tab.set('published');
      } else if (this.editingScheduledId) {
        await this.api.updateScheduled(this.editingScheduledId, {
          ...payload,
          scheduledAt: this.toIsoFromLocal(this.scheduledLocal),
        });
        this.ok.set('Programación actualizada.');
        this.tab.set('scheduled');
      } else if (this.scheduleMode) {
        await this.api.schedule(payload);
        this.ok.set('Noticia programada.');
        this.tab.set('scheduled');
      } else {
        const topic = await this.api.publishNow(payload);
        this.ok.set(
          topic.status === 'published'
            ? 'Noticia publicada.'
            : 'Noticia enviada a revisión (pendiente de aprobación).',
        );
        this.tab.set('published');
      }
      this.resetForm();
      await this.reload();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo guardar la noticia'));
    } finally {
      this.busy.set(false);
    }
  }

  startEditPublished(item: NewsTopic): void {
    this.editingTopicId = item.id;
    this.editingScheduledId = null;
    this.title = item.title;
    this.body = item.body;
    this.relatedForumId = item.relatedForumId ?? '';
    this.coverImageUrl = item.coverImageUrl ?? '';
    this.scheduleMode = false;
    this.scheduledLocal = '';
    this.tab.set('compose');
    this.error.set(null);
    this.ok.set(null);
    this.previewTick.update((n) => n + 1);
  }

  startEditScheduled(item: ScheduledNews): void {
    if (item.status !== 'scheduled') return;
    this.editingScheduledId = item.id;
    this.editingTopicId = null;
    this.title = item.title;
    this.body = item.body;
    this.relatedForumId = item.relatedForumId ?? '';
    this.coverImageUrl = item.coverImageUrl ?? '';
    this.scheduleMode = true;
    this.scheduledLocal = this.toLocalInput(item.scheduledAt);
    this.tab.set('compose');
    this.error.set(null);
    this.ok.set(null);
    this.previewTick.update((n) => n + 1);
  }

  cancelEdit(): void {
    this.resetForm();
    this.ok.set(null);
    this.error.set(null);
  }

  async deletePublished(item: NewsTopic): Promise<void> {
    if (
      !confirm(
        `¿Eliminar definitivamente «${item.title}» y todas sus respuestas?`,
      )
    ) {
      return;
    }
    this.busy.set(true);
    this.error.set(null);
    try {
      await this.api.deletePublished(item.id);
      if (this.editingTopicId === item.id) this.resetForm();
      this.ok.set('Noticia eliminada.');
      await this.reload();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo eliminar'));
    } finally {
      this.busy.set(false);
    }
  }

  async cancelScheduled(item: ScheduledNews): Promise<void> {
    if (item.status !== 'scheduled') return;
    if (!confirm(`¿Cancelar la programación de «${item.title}»?`)) return;
    this.busy.set(true);
    try {
      await this.api.cancelScheduled(item.id);
      await this.reload();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo cancelar'));
    } finally {
      this.busy.set(false);
    }
  }

  async deleteScheduled(item: ScheduledNews): Promise<void> {
    if (!confirm(`¿Eliminar «${item.title}» de la cola?`)) return;
    this.busy.set(true);
    try {
      await this.api.deleteScheduled(item.id);
      await this.reload();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo eliminar'));
    } finally {
      this.busy.set(false);
    }
  }

  async publishDue(): Promise<void> {
    this.busy.set(true);
    this.error.set(null);
    try {
      const n = await this.api.publishDueNow();
      this.ok.set(
        n > 0
          ? `Se publicaron ${n} noticia${n === 1 ? '' : 's'} programada${n === 1 ? '' : 's'}.`
          : 'No hay noticias pendientes de publicar ahora.',
      );
      await this.reload();
    } catch (err) {
      this.error.set(this.errMsg(err, 'No se pudo ejecutar la publicación'));
    } finally {
      this.busy.set(false);
    }
  }

  relatedLabel(id: string | null): string {
    return this.api.relatedLabel(id);
  }

  statusLabel(status: string): string {
    switch (status) {
      case 'published':
        return 'Publicada';
      case 'pending':
        return 'Pendiente';
      case 'rejected':
        return 'Rechazada';
      case 'scheduled':
        return 'Programada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  private resetForm(): void {
    this.title = '';
    this.body = '';
    this.relatedForumId = '';
    this.coverImageUrl = '';
    this.scheduleMode = false;
    this.scheduledLocal = '';
    this.editingTopicId = null;
    this.editingScheduledId = null;
    this.previewTick.update((n) => n + 1);
  }

  private toLocalInput(iso: string): string {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '';
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private toIsoFromLocal(value: string): string {
    const trimmed = value.trim();
    if (!trimmed) return '';
    const d = new Date(trimmed);
    if (Number.isNaN(d.getTime())) return trimmed;
    return d.toISOString();
  }

  private errMsg(err: unknown, fallback: string): string {
    if (err instanceof Error && err.message) return err.message;
    if (
      err &&
      typeof err === 'object' &&
      'message' in err &&
      typeof (err as { message: unknown }).message === 'string' &&
      (err as { message: string }).message
    ) {
      return (err as { message: string }).message;
    }
    return fallback;
  }
}
