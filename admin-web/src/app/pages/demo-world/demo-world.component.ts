import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  DemoWorldService,
  DemoWorldStatus,
} from '../../core/demo/demo-world.service';

@Component({
  selector: 'app-demo-world-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './demo-world.component.html',
  styleUrl: './demo-world.component.scss',
})
export class DemoWorldPageComponent implements OnInit {
  private readonly api = inject(DemoWorldService);

  readonly status = signal<DemoWorldStatus | null>(null);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly lastMessage = signal<string | null>(null);

  seedConfirm = '';
  wipeConfirm = '';

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.status.set(await this.api.fetchStatus());
    } catch (err) {
      this.status.set(null);
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste supabase/demo_world.sql en PRE?`
          : 'No se pudo consultar el estado',
      );
    } finally {
      this.loading.set(false);
    }
  }

  async seed(): Promise<void> {
    if (this.seedConfirm.trim().toUpperCase() !== 'SIMULAR') {
      this.error.set('Escribe SIMULAR para confirmar la carga.');
      return;
    }
    this.busy.set(true);
    this.error.set(null);
    this.lastMessage.set(null);
    try {
      const result = await this.api.seed();
      this.seedConfirm = '';
      if (result.status) this.status.set(result.status);
      else await this.reload();
      this.lastMessage.set(
        [result.message, result.loginHint].filter(Boolean).join(' '),
      );
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo cargar la simulación',
      );
    } finally {
      this.busy.set(false);
    }
  }

  async wipe(): Promise<void> {
    if (this.wipeConfirm.trim().toUpperCase() !== 'LIMPIAR') {
      this.error.set('Escribe LIMPIAR para confirmar el borrado demo.');
      return;
    }
    this.busy.set(true);
    this.error.set(null);
    this.lastMessage.set(null);
    try {
      const result = await this.api.wipe();
      this.wipeConfirm = '';
      await this.reload();
      this.lastMessage.set(
        `Demo eliminada: ${result.usersDeleted} usuarios, ${result.topicsDeleted} temas, ${result.repliesDeleted} respuestas, ${result.eventsDeleted} eventos.`,
      );
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo limpiar la simulación',
      );
    } finally {
      this.busy.set(false);
    }
  }
}
