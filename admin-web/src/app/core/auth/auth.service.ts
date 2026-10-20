import { Injectable, computed, signal } from '@angular/core';
import type { Session, User } from '@supabase/supabase-js';
import {
  StaffProfile,
  StaffRole,
  canAccessHermandadPortal,
  canAccessJunta,
  isAdminRole,
  isBrotherhoodAccount,
} from '../models/staff-profile';
import { getSupabase, isSupabaseConfigured } from '../supabase.client';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly sessionSignal = signal<Session | null>(null);
  private readonly profileSignal = signal<StaffProfile | null>(null);
  private readonly moderatedForumIdsSignal = signal<ReadonlySet<string>>(
    new Set(),
  );
  private readonly readySignal = signal(false);
  private readonly bootErrorSignal = signal<string | null>(null);

  /** Invalida applies en vuelo tras signOut / cambio de sesión. */
  private applyGeneration = 0;

  readonly session = this.sessionSignal.asReadonly();
  readonly profile = this.profileSignal.asReadonly();
  readonly moderatedForumIds = this.moderatedForumIdsSignal.asReadonly();
  readonly ready = this.readySignal.asReadonly();
  readonly bootError = this.bootErrorSignal.asReadonly();

  readonly user = computed<User | null>(() => this.sessionSignal()?.user ?? null);
  readonly isAdmin = computed(() => isAdminRole(this.profileSignal()?.role));
  /** Panel /app: solo admin. Hermandades usan isHermandadAccount → /hermandad. */
  readonly canAccess = computed(() =>
    canAccessJunta({ role: this.profileSignal()?.role }),
  );
  readonly isHermandadAccount = computed(() =>
    canAccessHermandadPortal({
      accountType: this.profileSignal()?.accountType,
      verified: this.profileSignal()?.verified,
    }),
  );
  /** Admin tiene prioridad si alguien fuera ambas cosas. */
  readonly homePath = computed(() => {
    if (this.canAccess()) return '/app/resumen';
    if (this.isHermandadAccount()) return '/hermandad';
    return '/login';
  });

  private initPromise: Promise<void> | null = null;

  init(): Promise<void> {
    if (this.initPromise) return this.initPromise;
    this.initPromise = this.bootstrap();
    return this.initPromise;
  }

  private async bootstrap(): Promise<void> {
    try {
      if (!isSupabaseConfigured()) {
        this.bootErrorSignal.set(
          'Falta configurar Supabase (npm run sync-env o environment.local.ts).',
        );
        return;
      }

      const supabase = getSupabase();
      const { data } = await supabase.auth.getSession();
      await this.applySession(data.session);

      supabase.auth.onAuthStateChange((_event, session) => {
        void this.applySession(session);
      });
    } catch (error) {
      this.bootErrorSignal.set(
        error instanceof Error ? error.message : 'Error al iniciar sesión',
      );
    } finally {
      this.readySignal.set(true);
    }
  }

  private async applySession(session: Session | null): Promise<void> {
    const gen = ++this.applyGeneration;

    if (!session?.user) {
      if (gen !== this.applyGeneration) return;
      this.sessionSignal.set(null);
      this.profileSignal.set(null);
      this.moderatedForumIdsSignal.set(new Set());
      return;
    }

    const context = await this.fetchStaffContext(session.user.id);
    if (gen !== this.applyGeneration) return;

    this.sessionSignal.set(session);
    this.profileSignal.set(context.profile);
    this.moderatedForumIdsSignal.set(context.moderatedForumIds);
  }

  private async fetchStaffContext(userId: string): Promise<{
    profile: StaffProfile;
    moderatedForumIds: ReadonlySet<string>;
  }> {
    const supabase = getSupabase();

    const baseSelect =
      'id, handle, display_name, role, avatar_url, account_type, verified';

    const [profileResult, modResult] = await Promise.all([
      supabase
        .from('profiles')
        .select(`${baseSelect}, panel_accent`)
        .eq('id', userId)
        .maybeSingle(),
      supabase
        .from('forum_moderators')
        .select('forum_id')
        .eq('profile_id', userId),
    ]);

    let profileRow: Record<string, unknown> | null =
      (profileResult.data as Record<string, unknown> | null) ?? null;
    let profileError = profileResult.error;
    // Si aún no se ejecutó hermandad_panel_accent.sql, no romper el login.
    if (
      profileError &&
      /panel_accent|schema cache|column/i.test(profileError.message)
    ) {
      const fallback = await supabase
        .from('profiles')
        .select(baseSelect)
        .eq('id', userId)
        .maybeSingle();
      profileRow = (fallback.data as Record<string, unknown> | null) ?? null;
      profileError = fallback.error;
    }

    const modRows = modResult.data;

    if (profileError) {
      throw profileError;
    }

    const role = (profileRow?.['role'] as StaffRole | undefined) ?? 'member';
    const panelAccentRaw =
      (profileRow?.['panel_accent'] as string | null | undefined) ?? null;
    const panelAccent =
      panelAccentRaw && /^#[0-9a-fA-F]{6}$/.test(panelAccentRaw)
        ? panelAccentRaw.toLowerCase()
        : null;
    const profile: StaffProfile = profileRow
      ? {
          id: String(profileRow['id']),
          handle: (profileRow['handle'] as string | null) ?? null,
          displayName: (profileRow['display_name'] as string | null) ?? null,
          role,
          avatarUrl: (profileRow['avatar_url'] as string | null) ?? null,
          accountType: String(profileRow['account_type'] ?? 'cofrade'),
          verified: Boolean(profileRow['verified']),
          panelAccent,
        }
      : {
          id: userId,
          handle: null,
          displayName: null,
          role: 'member',
          avatarUrl: null,
          accountType: 'cofrade',
          verified: false,
          panelAccent: null,
        };

    return {
      profile,
      moderatedForumIds: new Set(
        (modRows ?? []).map((row) => String(row.forum_id)),
      ),
    };
  }

  async signIn(email: string, password: string): Promise<void> {
    const supabase = getSupabase();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    const { data } = await supabase.auth.getSession();
    await this.applySession(data.session);

    if (this.isAdmin() || this.isHermandadAccount()) {
      return;
    }

    const profile = this.profileSignal();
    await this.signOut();

    if (isBrotherhoodAccount(profile?.accountType) && !profile?.verified) {
      throw new Error(
        'Tu hermandad aún no está verificada. Cuando se active podrás entrar al canal.',
      );
    }

    throw new Error(
      'Esta cuenta no tiene acceso. Usa la cuenta oficial verificada de tu hermandad.',
    );
  }

  /** Persiste el color de acento del panel hermandad en el perfil. */
  async setPanelAccent(hex: string | null): Promise<void> {
    const profile = this.profileSignal();
    if (!profile) throw new Error('Sesión no válida');

    const value =
      hex && /^#[0-9a-fA-F]{6}$/.test(hex) ? hex.toLowerCase() : null;

    const { error } = await getSupabase()
      .from('profiles')
      .update({ panel_accent: value })
      .eq('id', profile.id);
    if (error) throw error;

    this.profileSignal.set({ ...profile, panelAccent: value });
  }

  async signOut(): Promise<void> {
    // Invalida cualquier applySession en vuelo (p. ej. SIGNED_IN tardío).
    this.applyGeneration++;
    this.sessionSignal.set(null);
    this.profileSignal.set(null);
    this.moderatedForumIdsSignal.set(new Set());

    const supabase = getSupabase();
    await supabase.auth.signOut();
  }

  /**
   * Envío genérico: no revela si el email existe (anti-enumeración).
   * Si Auth responde rate-limit / SMTP, sí se propaga el error.
   */
  async requestPasswordReset(email: string): Promise<void> {
    const supabase = getSupabase();
    const trimmed = email.trim().toLowerCase();
    if (!trimmed) {
      throw new Error('Indica un email.');
    }
    // Exacto y en allow-list de Supabase (URL Configuration → Redirect URLs).
    const redirectTo = `${window.location.origin}/reset-password`;
    const { error } = await supabase.auth.resetPasswordForEmail(trimmed, {
      redirectTo,
    });
    if (error) throw error;
  }

  /** Tras el enlace del correo (evento PASSWORD_RECOVERY). */
  async updatePassword(password: string): Promise<void> {
    const supabase = getSupabase();
    const trimmed = password.trim();
    if (trimmed.length < 8) {
      throw new Error('La contraseña debe tener al menos 8 caracteres.');
    }
    const { error } = await supabase.auth.updateUser({ password: trimmed });
    if (error) throw error;
  }
}
