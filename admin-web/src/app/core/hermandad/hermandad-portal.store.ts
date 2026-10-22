import { Injectable, computed, inject, signal } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import {
  HermandadBoard,
  HermandadOfficialPost,
  HermandadPortalService,
  HermandadScheduledPost,
  OfficialCategory,
  PublishDestinations,
  PublishKindId,
  publishKindById,
} from './hermandad-portal.service';

export interface HermandadUpcomingEvent {
  id: string;
  title: string;
  startsAt: string;
  location: string | null;
  coverImageUrl: string | null;
  eventType: string;
  viewCount: number;
}

@Injectable({ providedIn: 'root' })
export class HermandadPortalStore {
  private readonly auth = inject(AuthService);
  private readonly api = inject(HermandadPortalService);

  readonly boards = signal<HermandadBoard[]>([]);
  readonly posts = signal<HermandadOfficialPost[]>([]);
  readonly deletedPosts = signal<HermandadOfficialPost[]>([]);
  readonly scheduledPosts = signal<HermandadScheduledPost[]>([]);
  readonly upcomingEvents = signal<HermandadUpcomingEvent[]>([]);
  readonly followerCount = signal(0);
  /** Primera carga (sin caché): la UI puede mostrar “Cargando…”. */
  readonly loading = signal(false);
  /** Revalidación en segundo plano (no vacía la pantalla). */
  readonly refreshing = signal(false);
  readonly error = signal<string | null>(null);
  readonly selectedTopicId = signal<string | null>(null);

  readonly primaryBoard = computed<HermandadBoard | null>(
    () => this.boards()[0] ?? null,
  );
  readonly activeTopicId = computed(
    () => this.selectedTopicId() ?? this.primaryBoard()?.topicId ?? null,
  );

  private lastLoadedAt = 0;
  private inflight: Promise<void> | null = null;
  /** Ventana en la que no se vuelve a pedir nada. */
  private static readonly FRESH_MS = 20_000;
  /** A partir de aquí, al navegar / recuperar foco se revalida en silencio. */
  private static readonly STALE_MS = 45_000;

  private hasCachedData(): boolean {
    return this.boards().length > 0 || this.lastLoadedAt > 0;
  }

  private isFresh(): boolean {
    return Date.now() - this.lastLoadedAt < HermandadPortalStore.FRESH_MS;
  }

  private isStale(): boolean {
    return Date.now() - this.lastLoadedAt >= HermandadPortalStore.STALE_MS;
  }

  /**
   * Stale-while-revalidate:
   * - Sin datos → espera la carga.
   * - Con datos → responde al instante y, si toca, refresca en background.
   * - `force: true` → espera el fetch sin vaciar la UI si ya había caché.
   */
  ensureLoaded(opts?: { force?: boolean }): Promise<void> {
    const hasData = this.hasCachedData();

    if (opts?.force) {
      return this.startFetch({ silent: hasData });
    }

    if (this.inflight) {
      return hasData ? Promise.resolve() : this.inflight;
    }

    if (!hasData) {
      return this.startFetch({ silent: false });
    }

    if (this.isFresh()) {
      return Promise.resolve();
    }

    void this.startFetch({ silent: true });
    return Promise.resolve();
  }

  /** Soft refresh al recuperar el foco de la pestaña. */
  revalidateIfStale(): void {
    if (!this.hasCachedData() || this.inflight || !this.isStale()) return;
    void this.startFetch({ silent: true });
  }

  /** Actualiza URLs de portada/escudo en la caché local del store. */
  patchBoardImages(
    topicId: string,
    patch: { coverImageUrl?: string | null; iconImageUrl?: string | null },
  ): void {
    this.boards.update((list) =>
      list.map((b) => {
        if (b.topicId !== topicId) return b;
        return {
          ...b,
          coverImageUrl:
            patch.coverImageUrl !== undefined
              ? patch.coverImageUrl
              : b.coverImageUrl,
          iconImageUrl:
            patch.iconImageUrl !== undefined
              ? patch.iconImageUrl
              : b.iconImageUrl,
        };
      }),
    );
  }

  async updateBoardBranding(
    topicId: string,
    input: {
      coverFile?: File | null;
      iconFile?: File | null;
      clearCover?: boolean;
      clearIcon?: boolean;
    },
  ): Promise<void> {
    let coverUrl: string | null | undefined;
    let iconUrl: string | null | undefined;
    let setCover = false;
    let setIcon = false;

    if (input.coverFile) {
      coverUrl = await this.api.uploadBoardAsset(
        topicId,
        'cover',
        input.coverFile,
      );
      setCover = true;
    } else if (input.clearCover) {
      coverUrl = null;
      setCover = true;
    }

    if (input.iconFile) {
      iconUrl = await this.api.uploadBoardAsset(
        topicId,
        'escudo',
        input.iconFile,
      );
      setIcon = true;
    } else if (input.clearIcon) {
      iconUrl = null;
      setIcon = true;
    }

    if (!setCover && !setIcon) return;

    await this.api.updateBoardImages(topicId, {
      coverImageUrl: coverUrl ?? null,
      setCover,
      iconImageUrl: iconUrl ?? null,
      setIcon,
    });

    this.patchBoardImages(topicId, {
      ...(setCover ? { coverImageUrl: coverUrl ?? null } : {}),
      ...(setIcon ? { iconImageUrl: iconUrl ?? null } : {}),
    });
  }

  private startFetch(opts: { silent: boolean }): Promise<void> {
    if (this.inflight) return this.inflight;
    this.inflight = this.reload({ silent: opts.silent }).finally(() => {
      this.inflight = null;
    });
    return this.inflight;
  }

  async reload(opts?: { silent?: boolean }): Promise<void> {
    const silent = opts?.silent === true && this.hasCachedData();
    const profile = this.auth.profile();
    if (!profile) {
      this.boards.set([]);
      this.posts.set([]);
      this.deletedPosts.set([]);
      this.scheduledPosts.set([]);
      this.upcomingEvents.set([]);
      this.followerCount.set(0);
      this.lastLoadedAt = 0;
      return;
    }

    if (silent) this.refreshing.set(true);
    else this.loading.set(true);
    this.error.set(null);

    try {
      const boards = await this.api.fetchAssignedBoards(profile.id);
      this.boards.set(boards);
      if (
        this.selectedTopicId() &&
        !boards.some((b) => b.topicId === this.selectedTopicId())
      ) {
        this.selectedTopicId.set(null);
      }
      const topicIds = boards.map((b) => b.topicId);
      const primaryId = topicIds[0] ?? null;

      // Primero lo crítico (posts): no bloquear la UI con papelera/programadas.
      const posts = await this.api
        .fetchOfficialPosts(profile.id, topicIds)
        .catch((err) => {
          console.warn('[hermandad] posts fetch failed', err);
          throw err;
        });
      this.posts.set(posts);
      this.lastLoadedAt = Date.now();
      // Ya hay datos útiles: quitar “Cargando…” aunque siga el resto.
      this.loading.set(false);

      const [deleted, scheduled, events, followers] = await Promise.all([
        this.api.fetchDeletedOfficialPosts(profile.id, topicIds).catch(() => []),
        this.api.fetchScheduledPosts(profile.id, topicIds).catch(() => []),
        this.api.fetchUpcomingOwnEvents(profile.id, 30).catch(() => []),
        primaryId
          ? this.api.countTopicFollowers(primaryId).catch(() => 0)
          : Promise.resolve(0),
      ]);
      this.deletedPosts.set(deleted);
      this.scheduledPosts.set(scheduled);
      this.upcomingEvents.set(events);
      this.followerCount.set(followers);
      this.lastLoadedAt = Date.now();
    } catch (err) {
      if (!silent) {
        this.error.set(
          err instanceof Error ? err.message : 'No se pudo cargar tu área',
        );
      } else {
        console.warn('[hermandad] soft refresh failed', err);
      }
    } finally {
      this.loading.set(false);
      this.refreshing.set(false);
    }
  }

  async publish(input: {
    topicId: string;
    kindId: PublishKindId;
    title: string;
    body: string;
    destinations: PublishDestinations;
    startsAtLocal?: string | null;
    location?: string | null;
    imageFile?: File | null;
    /** Si se indica, se programa en el tablón en vez de publicar ya. */
    scheduleAtLocal?: string | null;
  }): Promise<'published' | 'scheduled'> {
    const profile = this.auth.profile();
    if (!profile) throw new Error('Sesión no válida');
    if (!profile.verified) {
      throw new Error(
        'Tu cuenta aún no está verificada. Contacta con la Junta.',
      );
    }

    const kind = publishKindById(input.kindId);
    const board = this.boards().find((b) => b.topicId === input.topicId);
    const organizer = board?.hermandadName ?? profile.displayName ?? 'Hermandad';
    const handle = profile.handle ?? 'hermandad';

    if (!input.destinations.board) {
      throw new Error('La publicación debe salir al menos en tu tablón.');
    }

    if (input.destinations.calendar) {
      if (!kind.calendarType) {
        throw new Error('Este tipo no admite calendario.');
      }
      if (!input.startsAtLocal) {
        throw new Error('Indica fecha y hora para el calendario.');
      }
      if (!input.location?.trim()) {
        throw new Error(
          'Indica el lugar del acto para publicarlo en el calendario.',
        );
      }
    }

    let imageUrl: string | null = null;
    if (input.imageFile) {
      imageUrl = await this.api.uploadPostImage(input.topicId, input.imageFile);
    }

    const title = input.title.trim();
    const bodyParts = [title ? `**${title}**` : '', input.body.trim()].filter(
      Boolean,
    );
    const content = bodyParts.join('\n\n');
    const scheduleAt = input.scheduleAtLocal?.trim() || null;

    let createdReplyId: string | null = null;
    const wantsCalendar =
      !!input.destinations.calendar &&
      !!kind.calendarType &&
      !!input.startsAtLocal;
    const crestUrl = board?.iconImageUrl?.trim() || null;

    if (scheduleAt) {
      await this.api.createScheduledPost({
        topicId: input.topicId,
        authorId: profile.id,
        authorHandle: handle,
        body: content,
        category: kind.officialCategory as OfficialCategory,
        scheduledAtIso: new Date(scheduleAt).toISOString(),
        imageUrl,
        calendar: wantsCalendar
          ? {
              eventType: kind.calendarType!,
              startsAtIso: new Date(input.startsAtLocal!).toISOString(),
              location: input.location ?? null,
              title: title || kind.label,
              coverImageUrl: imageUrl,
              customIconUrl: crestUrl,
              organizerLabel: organizer,
            }
          : null,
      });
    } else {
      createdReplyId = await this.api.createOfficialPost({
        topicId: input.topicId,
        authorId: profile.id,
        authorHandle: handle,
        body: content,
        category: kind.officialCategory as OfficialCategory,
        imageUrl,
      });

      if (wantsCalendar) {
        try {
          await this.api.createCalendarEventFromPost({
            title: title || kind.label,
            subtitle: organizer,
            eventType: kind.calendarType!,
            startsAtIso: new Date(input.startsAtLocal!).toISOString(),
            location: input.location ?? null,
            organizerLabel: organizer,
            coverImageUrl: imageUrl,
            customIconUrl: crestUrl,
            createdBy: profile.id,
            sourceReplyId: createdReplyId,
          });
        } catch (err) {
          // No dejar noticia sin su evento: revertir el post.
          try {
            await this.api.softDeleteOfficialPost(createdReplyId);
          } catch (rollbackErr) {
            console.warn(
              'Rollback del post tras fallo de calendario',
              rollbackErr,
            );
          }
          const msg = err instanceof Error ? err.message : String(err ?? '');
          if (/location|not-null|23502/i.test(msg)) {
            throw new Error(
              'Falta el lugar del acto. Indícalo para publicar en el calendario. La publicación se ha revertido.',
            );
          }
          throw err instanceof Error
            ? err
            : new Error(
                'No se pudo crear el evento de calendario. La publicación se ha revertido.',
              );
        }
      }
    }

    await this.reload({ silent: true });
    return scheduleAt ? 'scheduled' : 'published';
  }

  async cancelScheduled(id: string): Promise<void> {
    await this.api.cancelScheduledPost(id);
    await this.reload({ silent: true });
  }

  async updatePublishedPost(input: {
    replyId: string;
    title: string;
    body: string;
    category: OfficialCategory;
    imageFile?: File | null;
    clearImage?: boolean;
    topicId: string;
    currentImageUrl?: string | null;
  }): Promise<void> {
    const title = input.title.trim();
    const bodyParts = [title ? `**${title}**` : '', input.body.trim()].filter(
      Boolean,
    );
    const content = bodyParts.join('\n\n');

    let imageUrl: string | null | undefined = undefined;
    let clearImage = input.clearImage === true;
    if (input.imageFile) {
      imageUrl = await this.api.uploadPostImage(
        input.topicId,
        input.imageFile,
      );
      clearImage = false;
    }

    await this.api.updateOfficialPost({
      replyId: input.replyId,
      body: content,
      category: input.category,
      imageUrl: imageUrl ?? null,
      clearImage,
    });
    await this.reload({ silent: true });
  }

  async deletePublishedPost(replyId: string): Promise<void> {
    await this.api.softDeleteOfficialPost(replyId);
    await this.reload({ silent: true });
  }

  async restorePublishedPost(replyId: string): Promise<void> {
    await this.api.restoreOfficialPost(replyId);
    await this.reload({ silent: true });
  }

  async hardDeletePublishedPost(replyId: string): Promise<void> {
    await this.api.hardDeleteOfficialPost(replyId);
    this.deletedPosts.update((list) => list.filter((p) => p.id !== replyId));
  }

  async deleteUpcomingEvent(eventId: string): Promise<void> {
    await this.api.deleteOwnCalendarEvent(eventId);
    this.upcomingEvents.update((list) => list.filter((e) => e.id !== eventId));
  }

  async updateUpcomingEvent(
    eventId: string,
    input: {
      title: string;
      startsAtIso: string;
      location?: string | null;
      eventType: string;
    },
  ): Promise<HermandadUpcomingEvent> {
    await this.api.updateOwnCalendarEvent(eventId, input);
    const prev = this.upcomingEvents().find((e) => e.id === eventId);
    const next: HermandadUpcomingEvent = {
      id: eventId,
      title: input.title.trim(),
      startsAt: input.startsAtIso,
      location: input.location?.trim() || null,
      coverImageUrl: prev?.coverImageUrl ?? null,
      eventType: input.eventType,
      viewCount: prev?.viewCount ?? 0,
    };
    this.upcomingEvents.update((list) =>
      list.map((e) => (e.id === eventId ? { ...e, ...next } : e)),
    );
    return next;
  }
}
