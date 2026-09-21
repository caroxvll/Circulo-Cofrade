import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  AdminUserRow,
  CommunityService,
  CreatedHermandadAccount,
  HERMANDAD_STATION_DAYS,
  HandleHit,
  HermandadAssignment,
  HermandadTopicOption,
} from '../../core/community/community.service';
import { HandleSearchComponent } from '../../shared/handle-search.component';
import { formatTimeAgo } from '../../core/utils/date';

type BoardDialog = 'create' | 'edit' | null;

@Component({
  selector: 'app-hermandades-page',
  standalone: true,
  imports: [FormsModule, HandleSearchComponent],
  templateUrl: './hermandades.component.html',
  styleUrl: './hermandades.component.scss',
})
export class HermandadesPageComponent implements OnInit {
  private readonly community = inject(CommunityService);

  readonly assignments = signal<HermandadAssignment[]>([]);
  readonly topics = signal<HermandadTopicOption[]>([]);
  readonly brotherhoods = signal<AdminUserRow[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly creating = signal(false);
  readonly linking = signal(false);
  readonly savingBoard = signal(false);
  readonly busyKey = signal<string | null>(null);
  readonly created = signal<CreatedHermandadAccount | null>(null);
  readonly boardDialog = signal<BoardDialog>(null);
  readonly editingBoard = signal<HermandadTopicOption | null>(null);

  readonly stationDays = HERMANDAD_STATION_DAYS;
  readonly timeAgo = formatTimeAgo;
  /** `null` = todos los días. */
  readonly dayFilter = signal<string | null>(null);

  boardSearch = '';
  boardDay: string = HERMANDAD_STATION_DAYS[2];
  boardName = '';
  boardCoverUrl = '';
  boardResetBody = false;

  displayName = '';
  handle = '';
  email = '';
  password = '';
  autoPassword = true;
  createTopicId = '';
  linkTopicId = '';
  selected: HandleHit | null = null;

  readonly filteredTopics = computed(() => {
    const q = this.boardSearch.trim().toLowerCase();
    const day = this.dayFilter();
    return this.topics().filter((t) => {
      if (day && t.processionDay !== day) return false;
      if (!q) return true;
      return (
        t.hermandadName.toLowerCase().includes(q) ||
        t.title.toLowerCase().includes(q)
      );
    });
  });

  readonly dayCounts = computed(() => {
    const counts = new Map<string, number>();
    for (const t of this.topics()) {
      const key = t.processionDay ?? '';
      if (!key) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    return counts;
  });

  ngOnInit(): void {
    void this.reload();
  }

  setDayFilter(day: string | null): void {
    this.dayFilter.set(day);
  }

  countForDay(day: string): number {
    return this.dayCounts().get(day) ?? 0;
  }

  shortDayLabel(day: string): string {
    return day
      .replace('Viernes de Dolores', 'V. Dolores')
      .replace('Sábado de Pasión', 'S. Pasión')
      .replace('Domingo de Ramos', 'D. Ramos')
      .replace('Domingo de Resurrección', 'Resurrección')
      .replace('Miércoles Santo', 'Mié. Santo')
      .replace('Sábado Santo', 'Sáb. Santo');
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [assignments, topics, brotherhoods] = await Promise.all([
        this.community.fetchHermandadAssignments(),
        this.community.fetchHermandadBoardTopics(),
        this.community.fetchBrotherhoodAccounts(80),
      ]);
      this.assignments.set(assignments);
      this.topics.set(topics);
      this.brotherhoods.set(brotherhoods);
      if (!this.linkTopicId && topics.length) this.linkTopicId = topics[0].id;
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  openCreateBoard(): void {
    this.editingBoard.set(null);
    this.boardDay = this.dayFilter() ?? HERMANDAD_STATION_DAYS[2];
    this.boardName = '';
    this.boardCoverUrl = '';
    this.boardResetBody = false;
    this.boardDialog.set('create');
  }

  openEditBoard(board: HermandadTopicOption): void {
    this.editingBoard.set(board);
    this.boardDay =
      board.processionDay &&
      (HERMANDAD_STATION_DAYS as readonly string[]).includes(board.processionDay)
        ? board.processionDay
        : HERMANDAD_STATION_DAYS[2];
    this.boardName = board.hermandadName;
    this.boardCoverUrl = board.coverImageUrl ?? '';
    this.boardResetBody = false;
    this.boardDialog.set('edit');
  }

  closeBoardDialog(): void {
    this.boardDialog.set(null);
    this.editingBoard.set(null);
  }

  async saveBoard(): Promise<void> {
    this.savingBoard.set(true);
    this.error.set(null);
    try {
      const mode = this.boardDialog();
      if (mode === 'create') {
        await this.community.createHermandadBoard({
          processionDay: this.boardDay,
          hermandadName: this.boardName,
          coverImageUrl: this.boardCoverUrl || null,
        });
      } else if (mode === 'edit') {
        const current = this.editingBoard();
        if (!current) return;
        await this.community.updateHermandadBoard({
          id: current.id,
          processionDay: this.boardDay,
          hermandadName: this.boardName,
          coverImageUrl: this.boardCoverUrl || null,
          resetBodyToTemplate: this.boardResetBody,
        });
      }
      this.closeBoardDialog();
      await this.reload();
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? err.message
          : 'No se pudo guardar el tablón (¿SQL hermandad_boards_admin.sql ejecutado?)',
      );
    } finally {
      this.savingBoard.set(false);
    }
  }

  async deleteBoard(board: HermandadTopicOption): Promise<void> {
    if (
      !confirm(
        `¿Eliminar el tablón «${board.title}»?\nSe quitarán también las cuentas vinculadas a ese tablón.`,
      )
    ) {
      return;
    }
    this.busyKey.set(`board:${board.id}`);
    this.error.set(null);
    try {
      await this.community.deleteHermandadBoard(board.id);
      await this.reload();
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo eliminar el tablón',
      );
    } finally {
      this.busyKey.set(null);
    }
  }

  async createAccount(): Promise<void> {
    this.creating.set(true);
    this.error.set(null);
    this.created.set(null);
    try {
      const result = await this.community.createHermandadAccount({
        email: this.email,
        handle: this.handle,
        displayName: this.displayName,
        password: this.autoPassword ? null : this.password,
        topicId: this.createTopicId || null,
      });
      this.created.set(result);
      this.displayName = '';
      this.handle = '';
      this.email = '';
      this.password = '';
      await this.reload();
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? err.message
          : 'No se pudo crear la cuenta (¿Edge Function desplegada?)',
      );
    } finally {
      this.creating.set(false);
    }
  }

  async linkAccount(): Promise<void> {
    if (!this.selected || !this.linkTopicId) {
      this.error.set('Elige cuenta y tablón.');
      return;
    }
    this.linking.set(true);
    this.error.set(null);
    try {
      await this.community.assignHermandadTopic(
        this.selected.id,
        this.linkTopicId,
      );
      this.selected = null;
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo vincular');
    } finally {
      this.linking.set(false);
    }
  }

  async remove(row: HermandadAssignment): Promise<void> {
    if (!confirm(`¿Quitar a @${row.handle} de «${row.topicTitle}»?`)) return;
    const key = `${row.profileId}:${row.topicId}`;
    this.busyKey.set(key);
    try {
      await this.community.removeHermandadAssignment(
        row.profileId,
        row.topicId,
      );
      this.assignments.update((list) =>
        list.filter(
          (a) => !(a.profileId === row.profileId && a.topicId === row.topicId),
        ),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo quitar');
    } finally {
      this.busyKey.set(null);
    }
  }

  async toggleVerified(user: AdminUserRow): Promise<void> {
    this.busyKey.set(`user:${user.id}`);
    this.error.set(null);
    try {
      await this.community.updateBrotherhoodProfile({
        profileId: user.id,
        verified: !user.verified,
      });
      this.brotherhoods.update((list) =>
        list.map((u) =>
          u.id === user.id ? { ...u, verified: !user.verified } : u,
        ),
      );
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo actualizar verificación',
      );
    } finally {
      this.busyKey.set(null);
    }
  }

  async renameAccount(user: AdminUserRow): Promise<void> {
    const next = prompt('Nombre oficial de la hermandad', user.displayName);
    if (next == null) return;
    this.busyKey.set(`user:${user.id}`);
    this.error.set(null);
    try {
      await this.community.updateBrotherhoodProfile({
        profileId: user.id,
        displayName: next,
      });
      this.brotherhoods.update((list) =>
        list.map((u) =>
          u.id === user.id ? { ...u, displayName: next.trim() } : u,
        ),
      );
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo renombrar',
      );
    } finally {
      this.busyKey.set(null);
    }
  }

  async copyPassword(): Promise<void> {
    const pwd = this.created()?.temporaryPassword;
    if (!pwd) return;
    await navigator.clipboard.writeText(pwd);
  }

  assignmentCount(topicId: string): number {
    return this.assignments().filter((a) => a.topicId === topicId).length;
  }
}
