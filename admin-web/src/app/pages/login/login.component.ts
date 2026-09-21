import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { isSupabaseConfigured } from '../../core/supabase.client';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss',
})
export class LoginComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  email = '';
  password = '';
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly configured = isSupabaseConfigured();
  readonly denied =
    this.route.snapshot.queryParamMap.get('denied') === '1';

  async submit(): Promise<void> {
    if (!this.configured) {
      this.error.set('Configura Supabase antes de entrar (npm run sync-env).');
      return;
    }
    this.loading.set(true);
    this.error.set(null);
    try {
      await this.auth.signIn(this.email.trim(), this.password);
      await this.router.navigateByUrl(this.auth.homePath());
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo iniciar sesión',
      );
    } finally {
      this.loading.set(false);
    }
  }
}
