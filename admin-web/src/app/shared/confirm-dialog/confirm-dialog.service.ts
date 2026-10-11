import { Injectable, signal } from '@angular/core';

export type ConfirmTone = 'default' | 'danger' | 'primary';

export interface ConfirmRequest {
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: ConfirmTone;
  /** Solo aviso: un botón, resuelve siempre true. */
  alertOnly?: boolean;
}

interface ConfirmState extends ConfirmRequest {
  resolve: (value: boolean) => void;
}

@Injectable({ providedIn: 'root' })
export class ConfirmDialogService {
  readonly state = signal<ConfirmState | null>(null);

  confirm(opts: ConfirmRequest): Promise<boolean> {
    this.state()?.resolve(false);
    return new Promise<boolean>((resolve) => {
      this.state.set({
        title: opts.title,
        message: opts.message,
        confirmLabel: opts.confirmLabel ?? 'Confirmar',
        cancelLabel: opts.cancelLabel ?? 'Cancelar',
        tone: opts.tone ?? 'default',
        alertOnly: false,
        resolve,
      });
    });
  }

  alert(opts: Omit<ConfirmRequest, 'alertOnly' | 'cancelLabel' | 'tone'> & {
    confirmLabel?: string;
  }): Promise<void> {
    this.state()?.resolve(false);
    return new Promise<void>((resolve) => {
      this.state.set({
        title: opts.title,
        message: opts.message,
        confirmLabel: opts.confirmLabel ?? 'Entendido',
        cancelLabel: '',
        tone: 'primary',
        alertOnly: true,
        resolve: () => resolve(),
      });
    });
  }

  settle(accepted: boolean): void {
    const current = this.state();
    if (!current) return;
    this.state.set(null);
    current.resolve(accepted);
  }
}
