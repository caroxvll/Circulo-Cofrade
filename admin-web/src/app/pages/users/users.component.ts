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
  search = '';
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
