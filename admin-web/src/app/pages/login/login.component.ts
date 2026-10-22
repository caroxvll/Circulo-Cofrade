import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import {
  checkPasswordRecoverRate,
  mapAuthEmailError,
  recordPasswordRecoverAttempt,
} from '../../core/auth/email-rate-limit';
import {
  CommunityService,
  HERMANDAD_STATION_DAYS,
  HermandadBoardKind,
} from '../../core/community/community.service';
import { isSupabaseConfigured } from '../../core/supabase.client';

type LoginView = 'login' | 'request' | 'forgot';

type FieldKey =
  | 'email'
  | 'password'
  | 'reqHermandad'
  | 'reqKind'
  | 'reqDay'
  | 'reqCity'
  | 'reqContact'
  | 'reqEmail'
  | 'reqPhone'
  | 'reqPassword'
  | 'reqPassword2'
  | 'forgotEmail';

const REMEMBER_KEY = 'cc_hermandad_login_email';
const FINGERPRINT_KEY = 'cc_access_fp';
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss',
})
export class LoginComponent {
  private readonly auth = inject(AuthService);
  private readonly community = inject(CommunityService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  readonly view = signal<LoginView>('login');
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly info = signal<string | null>(null);
  readonly showPassword = signal(false);
  readonly fieldErrors = signal<Partial<Record<FieldKey, string>>>({});
  readonly configured = isSupabaseConfigured();
  readonly denied =
    this.route.snapshot.queryParamMap.get('denied') === '1';

  email = this.readRememberedEmail();
  password = '';
  remember = !!this.email;

  reqHermandad = '';
  reqKind: HermandadBoardKind = 'semana_santa';
  reqDay: string = HERMANDAD_STATION_DAYS[2];
  reqCity = 'Sevilla';
  reqContact = '';
  reqEmail = '';
  reqPhone = '';
  reqMessage = '';
  reqPassword = '';
  reqPassword2 = '';
  /** Honeypot anti-bot (debe quedar vacío). */
  reqWebsite = '';

  readonly stationDays = HERMANDAD_STATION_DAYS;

  forgotEmail = this.email;

  fieldError(key: FieldKey): string | null {
    return this.fieldErrors()[key] ?? null;
  }

  hasFieldError(key: FieldKey): boolean {
    return !!this.fieldErrors()[key];
  }

  clearField(key: FieldKey): void {
    if (!this.fieldErrors()[key]) return;
    const next = { ...this.fieldErrors() };
    delete next[key];
    this.fieldErrors.set(next);
    if (this.error()) this.error.set(null);
  }

  showLogin(): void {
    this.view.set('login');
    this.resetMessages();
  }

  showRequest(): void {
    this.view.set('request');
    this.resetMessages();
    if (!this.reqEmail && this.email) this.reqEmail = this.email;
  }

  setReqKind(kind: HermandadBoardKind): void {
    this.reqKind = kind;
    this.clearField('reqKind');
    this.clearField('reqDay');
    if (kind === 'semana_santa' && !this.reqDay) {
      this.reqDay = HERMANDAD_STATION_DAYS[2];
    }
  }

  showForgot(): void {
    this.view.set('forgot');
    this.resetMessages();
    this.forgotEmail = this.email || this.forgotEmail;
  }

  togglePassword(): void {
    this.showPassword.update((v) => !v);
  }

  async submitLogin(): Promise<void> {
    if (!this.configured) {
      this.error.set('Configura Supabase antes de entrar (npm run sync-env).');
      return;
    }

    const errors: Partial<Record<FieldKey, string>> = {};
    const email = this.email.trim();
    if (!email) {
      errors.email = 'Indica el email de la hermandad.';
    } else if (!EMAIL_RE.test(email)) {
      errors.email = 'El email no parece válido.';
    }
    if (!this.password) {
      errors.password = 'Indica la contraseña.';
    }

    this.fieldErrors.set(errors);
    this.info.set(null);
    if (Object.keys(errors).length) {
      this.error.set('Revisa los campos marcados para continuar.');
      return;
    }

    this.loading.set(true);
    this.error.set(null);
    try {
      await this.auth.signIn(email, this.password);
      this.persistRemember();
      await this.router.navigateByUrl(this.auth.homePath());
    } catch (err) {
      const mapped = this.mapLoginError(err);
      this.error.set(mapped.message);
      if (mapped.fields) {
        this.fieldErrors.set(mapped.fields);
      }
    } finally {
      this.loading.set(false);
    }
  }

  async submitRequest(): Promise<void> {
    if (!this.configured) {
      this.error.set('Configura Supabase antes de enviar la solicitud.');
      return;
    }

    const errors: Partial<Record<FieldKey, string>> = {};
    const hermandad = this.reqHermandad.trim();
    const contact = this.reqContact.trim();
    const email = this.reqEmail.trim().toLowerCase();
    const city = this.reqCity.trim();
    const phone = this.reqPhone.trim();

    if (!hermandad) {
      errors.reqHermandad = 'Indica el nombre oficial de la hermandad.';
    } else if (hermandad.length < 2) {
      errors.reqHermandad = 'El nombre es demasiado corto.';
    }

    if (this.reqKind !== 'semana_santa' && this.reqKind !== 'glorias') {
      errors.reqKind = 'Elige el tipo de hermandad.';
    }

    if (this.reqKind === 'semana_santa') {
      if (!(HERMANDAD_STATION_DAYS as readonly string[]).includes(this.reqDay)) {
        errors.reqDay = 'Indica el día de salida.';
      }
    }

    if (!contact) {
      errors.reqContact = 'Indica una persona de contacto.';
    } else if (contact.length < 2) {
      errors.reqContact = 'El nombre de contacto es demasiado corto.';
    }

    if (!email) {
      errors.reqEmail = 'Indica un email de contacto.';
    } else if (!EMAIL_RE.test(email)) {
      errors.reqEmail = 'El email no parece válido.';
    }

    if (city.length > 80) {
      errors.reqCity = 'La ciudad es demasiado larga.';
    }
    if (phone.length > 40) {
      errors.reqPhone = 'El teléfono es demasiado largo.';
    }

    const password = this.reqPassword;
    const password2 = this.reqPassword2;
    if (!password || password.length < 8) {
      errors.reqPassword = 'Mínimo 8 caracteres.';
    } else if (password.length > 72) {
      errors.reqPassword = 'Máximo 72 caracteres.';
    }
    if (!password2) {
      errors.reqPassword2 = 'Repite la contraseña.';
    } else if (password !== password2) {
      errors.reqPassword2 = 'No coinciden.';
    }

    this.fieldErrors.set(errors);
    this.info.set(null);
    if (Object.keys(errors).length) {
      this.error.set(
        'Faltan datos obligatorios o hay algún campo incorrecto. Revisa lo marcado en rojo.',
      );
      return;
    }

    this.loading.set(true);
    this.error.set(null);
    try {
      await this.community.submitHermandadAccessRequest({
        hermandadName: hermandad,
        city,
        contactName: contact,
        contactEmail: email,
        contactPhone: phone,
        message: this.reqMessage,
        boardKind: this.reqKind,
        processionDay: this.reqKind === 'semana_santa' ? this.reqDay : '',
        password,
        clientFingerprint: this.fingerprint(),
        honeypot: this.reqWebsite,
      });
      this.info.set(
        'Solicitud enviada. Cuando la Junta la apruebe podrás entrar con este email y la contraseña que has elegido.',
      );
      this.fieldErrors.set({});
      this.reqHermandad = '';
      this.reqKind = 'semana_santa';
      this.reqDay = HERMANDAD_STATION_DAYS[2];
      this.reqCity = 'Sevilla';
      this.reqContact = '';
      this.reqEmail = '';
      this.reqPhone = '';
      this.reqMessage = '';
      this.reqPassword = '';
      this.reqPassword2 = '';
      this.reqWebsite = '';
    } catch (err) {
      const mapped = this.mapRequestError(err);
      this.error.set(mapped.message);
      if (mapped.fields) this.fieldErrors.set(mapped.fields);
    } finally {
      this.loading.set(false);
    }
  }

  async submitForgot(): Promise<void> {
    if (!this.configured) {
      this.error.set('Configura Supabase antes de continuar.');
      return;
    }

    const email = this.forgotEmail.trim().toLowerCase();
    const errors: Partial<Record<FieldKey, string>> = {};
    if (!email) {
      errors.forgotEmail = 'Indica el email de la cuenta.';
    } else if (!EMAIL_RE.test(email)) {
      errors.forgotEmail = 'El email no parece válido.';
    }

    this.fieldErrors.set(errors);
    this.info.set(null);
    this.error.set(null);
    if (Object.keys(errors).length) {
      this.error.set('Revisa el email marcado para continuar.');
      return;
    }

    const rate = checkPasswordRecoverRate(email);
    if (rate.blocked) {
      this.error.set(rate.message);
      this.fieldErrors.set({
        forgotEmail: 'Espera un poco antes de volver a intentarlo.',
      });
      return;
    }

    this.loading.set(true);
    try {
      await this.auth.requestPasswordReset(email);
      recordPasswordRecoverAttempt(email);
      this.info.set(
        'Si esa cuenta existe, recibirás un email con instrucciones. Si no llega en unos minutos, espera antes de pedirlo otra vez (el servicio de email tiene un cupo limitado).',
      );
    } catch (err) {
      const emailErr = mapAuthEmailError(err);
      if (emailErr) {
        // Contamos el intento igualmente: el cupo del servidor ya se consumió o está lleno.
        recordPasswordRecoverAttempt(email);
        this.error.set(emailErr);
        this.fieldErrors.set({
          forgotEmail: 'No se pudo enviar ahora. Prueba más tarde.',
        });
      } else {
        // Anti-enumeración: fallo genérico sin revelar si el email existe.
        recordPasswordRecoverAttempt(email);
        this.info.set(
          'Si esa cuenta existe, recibirás un email con instrucciones. Si no llega en unos minutos, espera antes de pedirlo otra vez.',
        );
      }
    } finally {
      this.loading.set(false);
    }
  }

  private resetMessages(): void {
    this.error.set(null);
    this.info.set(null);
    this.fieldErrors.set({});
  }

  private mapLoginError(err: unknown): {
    message: string;
    fields?: Partial<Record<FieldKey, string>>;
  } {
    const raw = err instanceof Error ? err.message : String(err ?? '');
    const lower = raw.toLowerCase();

    if (
      lower.includes('invalid login') ||
      lower.includes('invalid credentials') ||
      lower.includes('email or password')
    ) {
      return {
        message: 'Email o contraseña incorrectos. Compruébalos e inténtalo de nuevo.',
        fields: {
          email: 'Revisa este email.',
          password: 'Revisa esta contraseña.',
        },
      };
    }
    if (lower.includes('no tiene acceso') || lower.includes('no está verificada')) {
      return { message: raw };
    }
    if (lower.includes('network') || lower.includes('fetch')) {
      return {
        message: 'No hay conexión con el servidor. Comprueba tu red e inténtalo de nuevo.',
      };
    }
    return {
      message: raw || 'No se pudo iniciar sesión. Inténtalo de nuevo.',
    };
  }

  private requestErrorText(err: unknown): string {
    if (typeof err === 'string') return err;
    if (err instanceof Error && err.message.trim()) return err.message.trim();
    if (err && typeof err === 'object') {
      const e = err as Record<string, unknown>;
      const parts = [e['message'], e['details'], e['hint'], e['code']]
        .filter((x): x is string => typeof x === 'string' && x.trim().length > 0)
        .map((x) => x.trim());
      if (parts.length) return parts.join(' — ');
      try {
        return JSON.stringify(err);
      } catch {
        /* ignore */
      }
    }
    return String(err ?? '');
  }

  private mapRequestError(err: unknown): {
    message: string;
    fields?: Partial<Record<FieldKey, string>>;
  } {
    const raw = this.requestErrorText(err);
    const lower = raw.toLowerCase();
    console.error('[solicitud hermandad]', err, raw);

    if (
      lower.includes('could not find the function') ||
      lower.includes('pgrst202') ||
      (lower.includes('function') &&
        lower.includes('does not exist') &&
        lower.includes('submit_hermandad'))
    ) {
      return {
        message:
          'El servicio de solicitudes aún no está disponible. Contacta con la Junta o inténtalo más tarde.',
      };
    }

    if (lower.includes('demasiadas')) {
      return {
        message: 'Has enviado demasiadas solicitudes. Espera 24 horas e inténtalo de nuevo.',
      };
    }
    if (
      lower.includes('en uso') ||
      lower.includes('already been registered') ||
      lower.includes('already registered') ||
      lower.includes('user already')
    ) {
      return {
        message: 'Ese email ya está en uso. Usa otro correo.',
        fields: { reqEmail: 'Este email ya tiene una cuenta.' },
      };
    }
    if (
      (lower.includes('pendiente') && lower.includes('email')) ||
      lower.includes('pending_email') ||
      (lower.includes('duplicate key') && lower.includes('hermandad_access'))
    ) {
      return {
        message: 'Ya hay una solicitud pendiente con ese email. Te contactaremos cuando se revise.',
        fields: { reqEmail: 'Este email ya tiene una solicitud en curso.' },
      };
    }
    if (lower.includes('email no válido') || lower.includes('email no valido')) {
      return {
        message: 'Revisa el email de contacto.',
        fields: { reqEmail: 'Email no válido.' },
      };
    }
    if (lower.includes('contraseña')) {
      return {
        message: 'Revisa la contraseña (mínimo 8 caracteres).',
        fields: { reqPassword: 'Contraseña no válida.' },
      };
    }
    if (lower.includes('día de salida') || lower.includes('dia de salida')) {
      return {
        message: 'Indica el día de salida de Semana Santa.',
        fields: { reqDay: 'Elige el día de estación.' },
      };
    }
    if (lower.includes('tipo de hermandad')) {
      return {
        message: 'Elige Semana Santa de Sevilla o Hermandad de Gloria.',
        fields: { reqKind: 'Elige el tipo.' },
      };
    }
    if (
      lower.includes('nombre de hermandad no válido') ||
      lower.includes('nombre de hermandad no valido')
    ) {
      return {
        message: 'Revisa el nombre de la hermandad.',
        fields: { reqHermandad: 'Nombre no válido.' },
      };
    }
    if (
      lower.includes('nombre de contacto no válido') ||
      lower.includes('nombre de contacto no valido')
    ) {
      return {
        message: 'Revisa el nombre de contacto.',
        fields: { reqContact: 'Nombre no válido.' },
      };
    }
    if (lower.includes('contact_phone') && lower.includes('not-null')) {
      return {
        message:
          'Falta actualizar la RPC de solicitudes en Supabase (teléfono vacío). Ejecuta fix_hermandad_request_phone_null.sql.',
      };
    }
    if (lower.includes('permission denied') && lower.includes('auth')) {
      return {
        message:
          'No se pudo comprobar el email (permiso Auth). Ejecuta el SQL de solicitudes en Supabase.',
      };
    }
    if (
      lower.includes('password_enc') ||
      lower.includes('_hermandad_request_pwd_key') ||
      lower.includes('pgp_sym')
    ) {
      return {
        message:
          'Falta aplicar el SQL de contraseña en solicitudes (hermandad_access_request_password.sql).',
      };
    }

    // Siempre mostrar el texto del servidor (antes se tragaba y salía el genérico).
    if (raw.trim()) {
      return {
        message:
          raw.trim().length > 280 ? `${raw.trim().slice(0, 280)}…` : raw.trim(),
      };
    }

    return {
      message: 'No se pudo enviar la solicitud. Revisa los datos e inténtalo de nuevo.',
    };
  }

  private persistRemember(): void {
    try {
      if (this.remember) {
        localStorage.setItem(REMEMBER_KEY, this.email.trim().toLowerCase());
      } else {
        localStorage.removeItem(REMEMBER_KEY);
      }
    } catch {
      /* private mode */
    }
  }

  private readRememberedEmail(): string {
    try {
      return localStorage.getItem(REMEMBER_KEY) ?? '';
    } catch {
      return '';
    }
  }

  private fingerprint(): string {
    try {
      let fp = localStorage.getItem(FINGERPRINT_KEY);
      if (!fp) {
        fp =
          typeof crypto !== 'undefined' && 'randomUUID' in crypto
            ? crypto.randomUUID()
            : `fp_${Date.now()}_${Math.random().toString(36).slice(2)}`;
        localStorage.setItem(FINGERPRINT_KEY, fp);
      }
      return fp;
    } catch {
      return `fp_${Date.now()}`;
    }
  }
}
