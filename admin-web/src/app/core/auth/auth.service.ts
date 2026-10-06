import { Injectable, computed, signal } from '@angular/core';
import type { Session, User } from '@supabase/supabase-js';
import {
  StaffProfile,
  StaffRole,
  canAccessHermandadPortal,
  canAccessJunta,
  isAdminRole,
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

  readonly session = this.sessionSignal.asReadonly();
  readonly profile = this.profileSignal.asReadonly();
  readonly moderatedForumIds = this.moderatedForumIdsSignal.asReadonly();
  readonly ready = this.readySignal.asReadonly();
  readonly bootError = this.bootErrorSignal.asReadonly();

  readonly user = computed<User | null>(() => this.sessionSignal()?.user ?? null);
  readonly isAdmin = computed(() => isAdminRole(this.profileSignal()?.role));
  readonly canAccess = computed(() =>
    canAccessJunta({
      role: this.profileSignal()?.role,
      moderatedForumCount: this.moderatedForumIdsSignal().size,
    }),
  );
  readonly isHermandadAccount = computed(() =>
    canAccessHermandadPortal({
      accountType: this.profileSignal()?.accountType,
    }),
  );
  /** Junta tiene prioridad si alguien fuera ambas cosas. */
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
    this.sessionSignal.set(session);
    if (!session?.user) {
      this.profileSignal.set(null);
      this.moderatedForumIdsSignal.set(new Set());
      return;
    }
    await this.loadStaffContext(session.user.id);
  }

  private async loadStaffContext(userId: string): Promise<void> {
    const supabase = getSupabase();

    const [{ data: profileRow, error: profileError }, { data: modRows }] =
      await Promise.all([
        supabase
          .from('profiles')
          .select(
            'id, handle, display_name, role, avatar_url, account_type, verified',
          )
          .eq('id', userId)
          .maybeSingle(),
        supabase
          .from('forum_moderators')
          .select('forum_id')
          .eq('profile_id', userId),
      ]);

    if (profileError) {
      throw profileError;
    }

    const role = (profileRow?.role as StaffRole | undefined) ?? 'member';
    this.profileSignal.set(
      profileRow
        ? {
            id: profileRow.id as string,
            handle: (profileRow.handle as string | null) ?? null,
            displayName: (profileRow.display_name as string | null) ?? null,
            role,
            avatarUrl: (profileRow.avatar_url as string | null) ?? null,
            accountType: String(profileRow.account_type ?? 'cofrade'),
            verified: Boolean(profileRow.verified),
          }
        : {
            id: userId,
            handle: null,
            displayName: null,
            role: 'member',
            avatarUrl: null,
            accountType: 'cofrade',
            verified: false,
          },
    );
    this.moderatedForumIdsSignal.set(
      new Set((modRows ?? []).map((row) => String(row.forum_id))),
    );
  }

  async signIn(email: string, password: string): Promise<void> {
    const supabase = getSupabase();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    const { data } = await supabase.auth.getSession();
    await this.applySession(data.session);
    if (!this.canAccess() && !this.isHermandadAccount()) {
      await this.signOut();
      throw new Error(
        'Esta cuenta no tiene acceso. Usa una cuenta de Junta o de hermandad verificada.',
      );
    }
  }

  async signOut(): Promise<void> {
    const supabase = getSupabase();
    await supabase.auth.signOut();
    this.sessionSignal.set(null);
    this.profileSignal.set(null);
    this.moderatedForumIdsSignal.set(new Set());
  }
}
