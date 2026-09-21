import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import {
  PUBLISH_KINDS,
  PublishDestinations,
  PublishKindId,
  publishKindById,
} from '../../../core/hermandad/hermandad-portal.service';
import { HermandadPortalStore } from '../../../core/hermandad/hermandad-portal.store';

@Component({
  selector: 'app-hermandad-publish-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './hermandad-publish.component.html',
  styleUrl: '../hermandad-portal-shared.scss',
})
export class HermandadPublishPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  readonly store = inject(HermandadPortalStore);
  private readonly router = inject(Router);

  readonly kinds = PUBLISH_KINDS;
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);

  topicId = '';
  kindId: PublishKindId = 'noticia';
  title = '';
  body = '';
  location = '';
  startsAtLocal = '';
  imageFile: File | null = null;
  imagePreview: string | null = null;

  destBoard = true;
  destCalendar = false;
  destNoticias = false;

  get activeKind() {
    return publishKindById(this.kindId);
  }

  ngOnInit(): void {
    void this.ensureLoaded();
  }

  private async ensureLoaded(): Promise<void> {
    if (!this.store.boards().length) {
      await this.store.reload();
    }
    this.topicId = this.store.activeTopicId() ?? '';
    this.applyKindDefaults(this.kindId);
  }

  onKindChange(id: PublishKindId): void {
    this.kindId = id;
    this.applyKindDefaults(id);
  }

  private applyKindDefaults(id: PublishKindId): void {
    const kind = publishKindById(id);
    this.destBoard = true;
    this.destCalendar = kind.calendarDefault;
    this.destNoticias = kind.noticiasDefault;
    if (!kind.needsDate) {
      this.startsAtLocal = '';
    }
  }

  onImagePicked(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      this.error.set('La imagen no puede superar 5 MB.');
      return;
    }
    this.imageFile = file;
    if (this.imagePreview) URL.revokeObjectURL(this.imagePreview);
    this.imagePreview = URL.createObjectURL(file);
    this.error.set(null);
  }

  clearImage(): void {
    this.imageFile = null;
    if (this.imagePreview) URL.revokeObjectURL(this.imagePreview);
    this.imagePreview = null;
  }

  async submit(): Promise<void> {
    this.error.set(null);
    if (!this.auth.profile()?.verified) {
      this.error.set('Cuenta sin verificar: no puedes publicar todavía.');
      return;
    }
    if (!this.topicId) {
      this.error.set('Selecciona tu tablón.');
      return;
    }

    const destinations: PublishDestinations = {
      board: this.destBoard,
      calendar: this.destCalendar,
      noticias: this.destNoticias,
    };

    this.saving.set(true);
    try {
      await this.store.publish({
        topicId: this.topicId,
        kindId: this.kindId,
        title: this.title,
        body: this.body,
        destinations,
        startsAtLocal: this.startsAtLocal || null,
        location: this.location || null,
        imageFile: this.imageFile,
      });
      this.title = '';
      this.body = '';
      this.location = '';
      this.startsAtLocal = '';
      this.clearImage();
      this.applyKindDefaults(this.kindId);
      await this.router.navigateByUrl('/hermandad/publicaciones');
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo publicar',
      );
    } finally {
      this.saving.set(false);
    }
  }
}
