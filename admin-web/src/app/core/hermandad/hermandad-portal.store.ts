import { Injectable, computed, inject, signal } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import {
  HermandadBoard,
  HermandadOfficialPost,
  HermandadPortalService,
  OfficialCategory,
  PublishDestinations,
  PublishKindId,
  publishKindById,
} from './hermandad-portal.service';

@Injectable({ providedIn: 'root' })
export class HermandadPortalStore {
  private readonly auth = inject(AuthService);
  private readonly api = inject(HermandadPortalService);

  readonly boards = signal<HermandadBoard[]>([]);
  readonly posts = signal<HermandadOfficialPost[]>([]);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly selectedTopicId = signal<string | null>(null);

  readonly primaryBoard = computed(() => this.boards()[0] ?? null);
  readonly activeTopicId = computed(
    () => this.selectedTopicId() ?? this.primaryBoard()?.topicId ?? null,
  );

  async reload(): Promise<void> {
    const profile = this.auth.profile();
    if (!profile) {
      this.boards.set([]);
      this.posts.set([]);
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
      const posts = await this.api.fetchOfficialPosts(profile.id, topicIds);
      this.posts.set(posts);
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
  }): Promise<void> {
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

    await this.api.createOfficialPost({
      topicId: input.topicId,
      authorId: profile.id,
      authorHandle: handle,
      body: content,
      category: kind.officialCategory as OfficialCategory,
      imageUrl,
    });

    if (input.destinations.calendar && kind.calendarType && input.startsAtLocal) {
      const startsAtIso = new Date(input.startsAtLocal).toISOString();
      await this.api.createCalendarEventFromPost({
        title: title || kind.label,
        subtitle: organizer,
        eventType: kind.calendarType,
        startsAtIso,
        location: input.location ?? null,
        organizerLabel: organizer,
        coverImageUrl: imageUrl,
        createdBy: profile.id,
      });
    }

    // noticiasDefault / destinations.noticias: aún no crea portada ciudad
    // (evita desborde). Se activará con cola de revisión Junta.

    await this.reload();
  }
}
