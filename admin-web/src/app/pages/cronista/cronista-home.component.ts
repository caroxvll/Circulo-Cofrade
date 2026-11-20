import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
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

  readonly items = signal<HistoriaRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly kinds = HISTORIA_KIND_OPTIONS;
  readonly kindLabel = (kind: HistoriaRow['kind']) => this.historias.kindLabel(kind);
  readonly statusLabel = (status: HistoriaRow['status']) =>
    this.historias.statusLabel(status);

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.items.set(await this.historias.fetchMine());
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
}
