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
}

@Injectable({ providedIn: 'root' })
export class HermandadPortalStore {
  private readonly auth = inject(AuthService);
  private readonly api = inject(HermandadPortalService);

  readonly boards = signal<HermandadBoard[]>([]);
  readonly posts = signal<HermandadOfficialPost[]>([]);
  readonly scheduledPosts = signal<HermandadScheduledPost[]>([]);
  readonly upcomingEvents = signal<HermandadUpcomingEvent[]>([]);
  readonly followerCount = signal(0);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly selectedTopicId = signal<string | null>(null);

  readonly primaryBoard = computed<HermandadBoard | null>(
    () => this.boards()[0] ?? null,
  );
  readonly activeTopicId = computed(
    () => this.selectedTopicId() ?? this.primaryBoard()?.topicId ?? null,
  );

  async reload(): Promise<void> {
    const profile = this.auth.profile();
    if (!profile) {
      this.boards.set([]);
      this.posts.set([]);
      this.scheduledPosts.set([]);
      this.upcomingEvents.set([]);
      this.followerCount.set(0);
      return;
    }
    this.loading.set(true);
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

      const [posts, scheduled, events, followers] = await Promise.all([
        this.api.fetchOfficialPosts(profile.id, topicIds),
        this.api.fetchScheduledPosts(profile.id, topicIds).catch(() => []),
        this.api.fetchUpcomingOwnEvents(profile.id, 30),
        primaryId
          ? this.api.countTopicFollowers(primaryId).catch(() => 0)
          : Promise.resolve(0),
      ]);
      this.posts.set(posts);
      this.scheduledPosts.set(scheduled);
      this.upcomingEvents.set(events);
      this.followerCount.set(followers);
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo cargar tu área',
      );
    } finally {
      this.loading.set(false);
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
            console.warn('Rollback del post tras fallo de calendario', rollbackErr);
          }
          throw err instanceof Error
            ? err
            : new Error(
                'No se pudo crear el evento de calendario. La publicación se ha revertido.',
              );
        }
      }
    }

    await this.reload();
    return scheduleAt ? 'scheduled' : 'published';
  }

  async cancelScheduled(id: string): Promise<void> {
    await this.api.cancelScheduledPost(id);
    await this.reload();
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
    await this.reload();
  }

  async deletePublishedPost(replyId: string): Promise<void> {
    await this.api.softDeleteOfficialPost(replyId);
    await this.reload();
  }

  async deleteUpcomingEvent(eventId: string): Promise<void> {
    await this.api.deleteOwnCalendarEvent(eventId);
    this.upcomingEvents.update((list) => list.filter((e) => e.id !== eventId));
  }
}
