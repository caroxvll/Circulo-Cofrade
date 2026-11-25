import { Component, OnDestroy, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import {
  HISTORIA_KIND_OPTIONS,
  HistoriaKind,
  HistoriaPage,
  HistoriaStatus,
  HistoriasService,
} from '../../core/historias/historias.service';

interface PageDraft {
  body: string;
  caption: string;
  imageUrl: string | null;
  file: File | null;
  preview: string | null;
}

@Component({
  selector: 'app-cronista-editor-page',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './cronista-editor.component.html',
  styleUrl: './cronista-editor.component.scss',
})
export class CronistaEditorPageComponent implements OnInit, OnDestroy {
  private readonly historias = inject(HistoriasService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);

  readonly kinds = HISTORIA_KIND_OPTIONS;
  readonly isAdmin = this.auth.isAdmin;
  readonly publishLabel = (kind: HistoriaKind) =>
    this.historias.publishLabel(kind);

  get publishesDirectly(): boolean {
    return this.isAdmin();
  }

  get primarySaveLabel(): string {
    if (this.saving()) {
      if (this.status === 'published') return 'Guardando…';
      return this.publishesDirectly ? 'Publicando…' : 'Enviando…';
    }
    if (this.status === 'published') return 'Guardar cambios';
    if (this.publishesDirectly) return this.publishLabel(this.kind);
    return 'Enviar a revisión';
  }

  historiaId: string | null = null;
  status: HistoriaStatus = 'draft';
  reviewNote: string | null = null;
  title = '';
  excerpt = '';
  kind: HistoriaKind = 'libro';
  coverFile: File | null = null;
  coverPreview: string | null = null;
  coverUrl: string | null = null;
  scheduleLocal = '';
  pages: PageDraft[] = [this.emptyPage()];
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);
  readonly loading = signal(false);

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.historiaId = id;
      void this.load(id);
      return;
    }
    const tipo = this.route.snapshot.queryParamMap.get('tipo');
    if (tipo === 'libro' || tipo === 'articulo') {
      this.kind = tipo;
    }
    this.scheduleLocal = this.toDatetimeLocal(null);
  }

  ngOnDestroy(): void {
    this.revokeAll();
  }

  async load(id: string): Promise<void> {
    this.loading.set(true);
    try {
      const row = await this.historias.fetchById(id);
      if (!row) {
        this.error.set('No se encontró esa historia.');
        return;
      }
      this.title = row.title;
      this.excerpt = row.excerpt;
      this.kind = row.kind;
      this.status = row.status;
      this.reviewNote = row.reviewNote;
      this.coverUrl = row.coverImageUrl;
      this.scheduleLocal = this.toDatetimeLocal(row.scheduledAt);
      this.pages =
        row.pages.length > 0
          ? row.pages.map((page) => ({
              body: page.body,
              caption: page.caption ?? '',
              imageUrl: page.image_url ?? null,
              file: null,
              preview: null,
            }))
          : [this.emptyPage()];
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo abrir.');
    } finally {
      this.loading.set(false);
    }
  }

  applyWrap(
    index: number,
    area: HTMLTextAreaElement,
    before: string,
    after: string,
  ): void {
    const start = area.selectionStart;
    const end = area.selectionEnd;
    const value = this.pages[index].body;
    const selected = value.slice(start, end) || 'texto';
    const next = `${value.slice(0, start)}${before}${selected}${after}${value.slice(end)}`;
    this.pages[index] = { ...this.pages[index], body: next };
    queueMicrotask(() => {
      area.focus();
      const cursor = start + before.length + selected.length + after.length;
      area.setSelectionRange(cursor, cursor);
    });
  }

  applyHeading(index: number, area: HTMLTextAreaElement): void {
    const start = area.selectionStart;
    const value = this.pages[index].body;
    const lineStart = value.lastIndexOf('\n', Math.max(0, start - 1)) + 1;
    const lineEnd = value.indexOf('\n', start);
    const end = lineEnd === -1 ? value.length : lineEnd;
    const line = value.slice(lineStart, end);
    const stripped = line.replace(/^#{1,3}\s+/, '');
    const nextLine = line.startsWith('#') ? stripped : `## ${stripped || 'Título'}`;
    const next = `${value.slice(0, lineStart)}${nextLine}${value.slice(end)}`;
    this.pages[index] = { ...this.pages[index], body: next };
    queueMicrotask(() => area.focus());
  }

  addPage(): void {
    if (this.pages.length >= 30) return;
    this.pages = [...this.pages, this.emptyPage()];
  }

  removePage(index: number): void {
    if (this.pages.length <= 1) return;
    this.revoke(this.pages[index].preview);
    this.pages = this.pages.filter((_, i) => i !== index);
  }

  onCover(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0] ?? null;
    if (!file) return;
    this.revoke(this.coverPreview);
    this.coverFile = file;
    this.coverPreview = URL.createObjectURL(file);
  }

  onPageImage(index: number, event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0] ?? null;
    if (!file) return;
    this.revoke(this.pages[index].preview);
    this.pages[index] = {
      ...this.pages[index],
      file,
      preview: URL.createObjectURL(file),
    };
  }

  clearPageImage(index: number): void {
    this.revoke(this.pages[index].preview);
    this.pages[index] = {
      ...this.pages[index],
      file: null,
      preview: null,
      imageUrl: null,
    };
  }

  async save(status: HistoriaStatus): Promise<void> {
    if (!this.publishesDirectly && status === 'published' && this.status !== 'published') {
      status = 'pending_review';
    }
    this.error.set(null);
    if (this.title.trim().length < 3) {
      this.error.set('El título es demasiado corto.');
      return;
    }
    const filled = this.pages.filter(
      (p) => p.body.trim() || p.file || p.imageUrl,
    );
    if (!filled.length) {
      this.error.set('Añade al menos una página con texto o foto.');
      return;
    }
    if (status === 'scheduled') {
      const when = this.scheduleLocal
        ? new Date(this.scheduleLocal)
        : null;
      if (!when || Number.isNaN(when.getTime()) || when.getTime() < Date.now() + 5 * 60 * 1000) {
        this.error.set('Elige un momento al menos 5 minutos más adelante.');
        return;
      }
    }

    this.saving.set(true);
    try {
      let id = this.historiaId;
      const firstPages: HistoriaPage[] = filled.map((p) => ({
        body: p.body.trim() || (p.file || p.imageUrl ? ' ' : ''),
        caption: p.caption.trim() || undefined,
        image_url: p.imageUrl || undefined,
      }));

      if (!id) {
        const created = await this.historias.create({
          title: this.title,
          excerpt: this.excerpt,
          kind: this.kind,
          pages: firstPages,
          status,
          coverImageUrl: this.coverUrl,
          scheduledAt: this.scheduledIso(status),
        });
        id = created.id;
        this.historiaId = id;
      }

      let coverImageUrl = this.coverUrl;
      if (this.coverFile) {
        coverImageUrl = await this.historias.uploadCover(id, this.coverFile);
      }

      const pages: HistoriaPage[] = [];
      for (const draft of filled) {
        let imageUrl = draft.imageUrl ?? undefined;
        if (draft.file) {
          imageUrl = await this.historias.uploadPageImage(id, draft.file);
        }
        pages.push({
          body: draft.body.trim(),
          caption: draft.caption.trim() || undefined,
          image_url: imageUrl,
        });
      }

      await this.historias.update(id, {
        title: this.title,
        excerpt: this.excerpt,
        kind: this.kind,
        pages,
        status,
        coverImageUrl,
        scheduledAt: this.scheduledIso(status),
      });
      await this.router.navigateByUrl('/cronista');
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? err.message
          : 'No se pudo guardar. Revisa que historias.sql esté ejecutado.',
      );
    } finally {
      this.saving.set(false);
    }
  }

  private scheduledIso(status: HistoriaStatus): string | null {
    if (status !== 'scheduled' || !this.scheduleLocal) return null;
    const when = new Date(this.scheduleLocal);
    if (Number.isNaN(when.getTime())) return null;
    return when.toISOString();
  }

  private toDatetimeLocal(iso: string | null): string {
    const source = iso ? new Date(iso) : new Date(Date.now() + 2 * 60 * 60 * 1000);
    if (Number.isNaN(source.getTime())) {
      return this.toDatetimeLocal(null);
    }
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${source.getFullYear()}-${pad(source.getMonth() + 1)}-${pad(source.getDate())}T${pad(source.getHours())}:${pad(source.getMinutes())}`;
  }

  private emptyPage(): PageDraft {
    return { body: '', caption: '', imageUrl: null, file: null, preview: null };
  }

  private revoke(url: string | null): void {
    if (url) URL.revokeObjectURL(url);
  }

  private revokeAll(): void {
    this.revoke(this.coverPreview);
    for (const page of this.pages) this.revoke(page.preview);
  }
}
