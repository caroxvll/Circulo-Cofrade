import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/auth/auth.service';
import {
  AdminUserRow,
  CommunityService,
  SignupStats,
} from '../../core/community/community.service';
import { formatDateTime, formatTimeAgo } from '../../core/utils/date';

@Component({
  selector: 'app-users-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './users.component.html',
  styleUrl: './users.component.scss',
})
export class UsersPageComponent implements OnInit {
  private readonly community = inject(CommunityService);
  private readonly auth = inject(AuthService);

  readonly users = signal<AdminUserRow[]>([]);
  readonly stats = signal<SignupStats | null>(null);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly filter = signal<'all' | 'admin' | 'brotherhood' | 'suspended'>('all');
  readonly editingUser = signal<AdminUserRow | null>(null);
  readonly editSaving = signal(false);
  readonly editError = signal<string | null>(null);
  search = '';
  editDisplayName = '';
  editHandle = '';
  editEmail = '';
  editPassword = '';
  readonly timeAgo = formatTimeAgo;
  readonly dateTime = formatDateTime;
  readonly selfId = () => this.auth.profile()?.id;

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [stats, users] = await Promise.all([
        this.community.fetchSignupStats(),
        this.community.searchUsers(this.search),
      ]);
      this.stats.set(stats);
      this.users.set(users);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async onSearch(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      this.users.set(await this.community.searchUsers(this.search));
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'Error de búsqueda');
    } finally {
      this.loading.set(false);
    }
  }

  visibleUsers(): AdminUserRow[] {
    const list = this.users();
    switch (this.filter()) {
      case 'admin':
        return list.filter((u) => u.role === 'admin');
      case 'brotherhood':
        return list.filter((u) => u.accountType === 'brotherhood');
      case 'suspended':
        return list.filter((u) => !!u.suspendedAt);
      default:
        return list;
    }
  }

  async toggleAdmin(user: AdminUserRow): Promise<void> {
    if (user.id === this.selfId()) {
      this.error.set('No puedes cambiar tu propio rol desde aquí.');
      return;
    }
    const next = user.role === 'admin' ? 'member' : 'admin';
    const label = next === 'admin' ? 'promover a admin' : 'quitar admin';
    if (!confirm(`¿Seguro que quieres ${label} a @${user.handle}?`)) return;
    this.busyId.set(user.id);
    try {
      await this.community.setUserRole(user.id, next);
      this.users.update((list) =>
        list.map((u) => (u.id === user.id ? { ...u, role: next } : u)),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cambiar el rol');
    } finally {
      this.busyId.set(null);
    }
  }

  async toggleVerified(user: AdminUserRow): Promise<void> {
    this.busyId.set(user.id);
    try {
      await this.community.setVerified(user.id, !user.verified);
      this.users.update((list) =>
        list.map((u) =>
          u.id === user.id ? { ...u, verified: !user.verified } : u,
        ),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo verificar');
    } finally {
      this.busyId.set(null);
    }
  }

  async toggleSuspend(user: AdminUserRow): Promise<void> {
    if (user.id === this.selfId()) {
      this.error.set('No puedes suspenderte a ti mismo.');
      return;
    }
    this.busyId.set(user.id);
    try {
      if (user.suspendedAt) {
        await this.community.unsuspendProfile(user.id);
        this.users.update((list) =>
          list.map((u) =>
            u.id === user.id
              ? { ...u, suspendedAt: null, suspendedReason: null }
              : u,
          ),
        );
      } else {
        const reason =
          prompt('Motivo de suspensión', 'Incumplimiento de normas') ?? '';
        if (!reason.trim()) {
          this.busyId.set(null);
          return;
        }
        await this.community.suspendProfile(user.id, reason);
        this.users.update((list) =>
          list.map((u) =>
            u.id === user.id
              ? {
                  ...u,
                  suspendedAt: new Date().toISOString(),
                  suspendedReason: reason,
                }
              : u,
          ),
        );
      }
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo suspender');
    } finally {
      this.busyId.set(null);
    }
  }

  openEdit(user: AdminUserRow): void {
    this.editingUser.set(user);
    this.editDisplayName = user.displayName;
    this.editHandle = user.handle;
    this.editEmail = user.email ?? '';
    this.editPassword = '';
    this.editError.set(null);
  }

  closeEdit(): void {
    if (this.editSaving()) return;
    this.editingUser.set(null);
    this.editError.set(null);
    this.editPassword = '';
  }

  async saveEdit(): Promise<void> {
    const user = this.editingUser();
    if (!user) return;

    const displayName = this.editDisplayName.trim();
    const handle = this.editHandle.replace(/^@/, '').trim().toLowerCase();
    const email = this.editEmail.trim().toLowerCase();
    const password = this.editPassword.trim();

    if (displayName.length < 2) {
      this.editError.set('El nombre debe tener al menos 2 caracteres.');
      return;
    }
    if (handle.length < 2 || !/^[a-z0-9_]+$/.test(handle)) {
      this.editError.set('Handle: solo a-z, 0-9 y _ (mín. 2).');
      return;
    }
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      this.editError.set('Indica un email válido.');
      return;
    }
    if (password && password.length < 8) {
      this.editError.set('La contraseña nueva debe tener al menos 8 caracteres.');
      return;
    }

    const emailChanged = email !== (user.email ?? '').toLowerCase();
    if (emailChanged) {
      if (
        !confirm(
          `Vas a cambiar el email de @${user.handle} a:\n${email}\n\n` +
            'Ese será el nuevo acceso de login. ¿Continuar?',
        )
      ) {
        return;
      }
    }

    this.editSaving.set(true);
    this.editError.set(null);
    this.error.set(null);
    try {
      const result = await this.community.updateUser({
        profileId: user.id,
        displayName,
        handle,
        email,
        password: password || null,
      });
      this.users.update((list) =>
        list.map((u) =>
          u.id === user.id
            ? {
                ...u,
                displayName: result.displayName,
                handle: result.handle,
                email: result.email,
              }
            : u,
        ),
      );
      this.editingUser.set(null);
      this.editPassword = '';
      const bits = [
        result.profileUpdated ? 'perfil' : null,
        result.emailUpdated ? 'email' : null,
        result.passwordUpdated ? 'contraseña' : null,
      ].filter(Boolean);
      alert(
        bits.length
          ? `Actualizado @${result.handle} (${bits.join(', ')}).`
          : `Sin cambios en @${result.handle}.`,
      );
    } catch (err) {
      this.editError.set(
        err instanceof Error ? err.message : 'No se pudo guardar',
      );
    } finally {
      this.editSaving.set(false);
    }
  }

  async deleteUser(user: AdminUserRow): Promise<void> {
    if (user.id === this.selfId()) {
      this.error.set('No puedes eliminarte a ti mismo.');
      return;
    }
    if (
      !confirm(
        `¿Eliminar a @${user.handle}?\n\n` +
          'Se borrará la cuenta (Auth + perfil), sus temas y sus comentarios.\n' +
          'No se tocan los tablones del foro Hermandades ni temas de sistema.',
      )
    ) {
      return;
    }
    if (
      !confirm(
        `Última confirmación: borrar permanentemente a @${user.handle}. Esta acción no se puede deshacer.`,
      )
    ) {
      return;
    }

    this.busyId.set(user.id);
    this.error.set(null);
    try {
      const result = await this.community.deleteUser(user.id, {
        deleteContent: true,
      });
      this.users.update((list) => list.filter((u) => u.id !== user.id));
      const stats = this.stats();
      if (stats) {
        this.stats.set({
          ...stats,
          total: Math.max(0, stats.total - 1),
        });
      }
      alert(
        `Eliminado @${user.handle}.\n` +
          `Temas: ${result.deletedTopics} · Comentarios: ${result.deletedReplies}`,
      );
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo eliminar el usuario',
      );
    } finally {
      this.busyId.set(null);
    }
  }
}
