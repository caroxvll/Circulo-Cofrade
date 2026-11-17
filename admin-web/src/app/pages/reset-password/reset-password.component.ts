import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { getSupabase, isSupabaseConfigured } from '../../core/supabase.client';

@Component({
  selector: 'app-reset-password',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './reset-password.component.html',
  styleUrl: './reset-password.component.scss',
})
export class ResetPasswordComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly configured = isSupabaseConfigured();
  readonly ready = signal(false);
  readonly canReset = signal(false);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly done = signal(false);

  password = '';
  password2 = '';
  showPassword = false;

  async ngOnInit(): Promise<void> {
    if (!this.configured) {
      this.ready.set(true);
      return;
    }

    await this.auth.init();
    const supabase = getSupabase();

    const { data } = await supabase.auth.getSession();
    if (data.session) {
      this.canReset.set(true);
    }

    supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY' || (event === 'SIGNED_IN' && session)) {
        this.canReset.set(true);
      }
    });

    this.ready.set(true);
  }

  async submit(): Promise<void> {
    this.error.set(null);
    const p1 = this.password.trim();
    const p2 = this.password2.trim();

    if (p1.length < 8) {
      this.error.set('La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (p1 !== p2) {
      this.error.set('Las contraseñas no coinciden.');
      return;
    }

    this.loading.set(true);
    try {
      await this.auth.updatePassword(p1);
      this.done.set(true);
      // Tras cambiar, la sesión sigue activa: ir al destino según perfil.
      await this.auth.init();
      setTimeout(() => {
        void this.router.navigateByUrl(this.auth.homePath());
      }, 1200);
    } catch (e) {
      this.error.set(
        e instanceof Error
          ? e.message
          : 'No se pudo actualizar la contraseña. Solicita un enlace nuevo.',
      );
    } finally {
      this.loading.set(false);
    }
  }
}
