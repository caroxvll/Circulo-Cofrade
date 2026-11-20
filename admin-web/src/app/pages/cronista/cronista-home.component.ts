import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import {
  HISTORIA_KIND_OPTIONS,
  HistoriaRow,
  HistoriasService,
} from '../../core/historias/historias.service';

@Component({
  selector: 'app-cronista-home-page',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './cronista-home.component.html',
  styleUrl: './cronista-home.component.scss',
})
export class CronistaHomePageComponent implements OnInit {
  private readonly historias = inject(HistoriasService);
  private readonly auth = inject(AuthService);

  readonly items = signal<HistoriaRow[]>([]);
  readonly pending = signal<HistoriaRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly kinds = HISTORIA_KIND_OPTIONS;
  readonly isAdmin = this.auth.isAdmin;
  readonly kindLabel = (kind: HistoriaRow['kind']) => this.historias.kindLabel(kind);
  readonly statusLabel = (status: HistoriaRow['status']) =>
    this.historias.statusLabel(status);

  ngOnInit(): void {
    void this.reload();
  }

  authorLine(item: HistoriaRow): string {
    const name = item.authorDisplayName?.trim();
    const handle = item.authorHandle?.trim();
    if (name && handle) return `${name} · @${handle.replace(/^@/, '')}`;
    return name || handle || 'Cronista';
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.items.set(await this.historias.fetchMine());
      if (this.isAdmin()) {
        try {
          this.pending.set(await this.historias.fetchPendingReview());
        } catch {
          this.pending.set([]);
        }
      } else {
        this.pending.set([]);
      }
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? err.message
          : 'No se pudieron cargar tus historias. ¿Ejecutaste historias.sql?',
      );
    } finally {
      this.loading.set(false);
    }
  }

  async approve(item: HistoriaRow): Promise<void> {
    try {
      await this.historias.setStatus(item.id, 'published', { reviewNote: null });
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo aprobar.');
    }
  }

  async returnToAuthor(item: HistoriaRow): Promise<void> {
    const note = window.prompt('Motivo para el cronista (opcional)', '') ?? '';
    try {
      await this.historias.setStatus(item.id, 'draft', { reviewNote: note.trim() || null });
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo devolver.');
    }
  }
}
