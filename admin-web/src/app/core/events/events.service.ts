import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { parseHermandadTopicTitle } from '../community/community.service';
import { organizerMatchScore } from '../hermandad/season-acts';
import { getSupabase } from '../supabase.client';
import {
  CALENDAR_EVENT_TYPES,
  CalendarEventInput,
  CalendarEventListQuery,
  CalendarEventRow,
  CalendarEventStatus,
  CalendarEventType,
  EventLiveForceState,
  OrganizerLogo,
  SeasonPaso,
  eventTypeCellLabel,
  parseTimeSlots,
  seasonActDayLabel,
} from './events.models';

const CALENDAR_SHOW_BOARD_LINK_KEY = 'calendar_show_board_link';

const EVENT_SELECT =
  'id, title, subtitle, event_type, starts_at, ends_at, span_until, live_force_state, day_label, location, admission_label, time_slots, organizer_label, custom_icon_url, cover_image_url, cover_image_credit, status, created_by, created_at, updated_at, paso, season_n, with_retranqueo, profiles!created_by(handle)';

@Injectable({ providedIn: 'root' })
export class EventsService {
  private readonly auth = inject(AuthService);

  async listEvents(query: CalendarEventListQuery = {}): Promise<CalendarEventRow[]> {
    if (!this.auth.isAdmin()) return [];

    const status = query.status ?? 'published';
    const range = query.range ?? 'upcoming';
    const limit = query.limit ?? 120;

    let req = getSupabase()
      .from('calendar_events')
      .select(EVENT_SELECT)
      .limit(limit);

    if (status !== 'all') {
      req = req.eq('status', status);
    }

    if (query.eventType && query.eventType !== 'all') {
      req = req.eq('event_type', query.eventType);
    }

    if (range === 'upcoming') {
      req = req.gte('starts_at', startOfLocalDayIso()).order('starts_at', {
        ascending: true,
      });
    } else if (range === 'past') {
      req = req.lt('starts_at', startOfLocalDayIso()).order('starts_at', {
        ascending: false,
      });
    } else {
      req = req.order('starts_at', { ascending: true });
    }

    const search = query.search?.trim();
    if (search) {
      const safe = search.replace(/[%_,]/g, '');
      if (safe) {
        req = req.or(
          `title.ilike.%${safe}%,subtitle.ilike.%${safe}%,location.ilike.%${safe}%,organizer_label.ilike.%${safe}%`,
        );
      }
    }

    const { data, error } = await req;
    if (error) throw error;
    return (data ?? []).map((row) => this.mapRow(row as Record<string, unknown>));
  }

  async fetchEventById(eventId: string): Promise<CalendarEventRow | null> {
    if (!this.auth.isAdmin()) return null;
    const id = eventId.trim();
    if (!id) return null;
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .select(EVENT_SELECT)
      .eq('id', id)
      .maybeSingle();
    if (error) throw error;
    return data ? this.mapRow(data as Record<string, unknown>) : null;
  }

  async countPending(): Promise<number> {
    if (!this.auth.isAdmin()) return 0;
    const { count, error } = await getSupabase()
      .from('calendar_events')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending_review');
    if (error) throw error;
    return count ?? 0;
  }

  async createEvent(input: CalendarEventInput): Promise<CalendarEventRow> {
    const userId = this.auth.user()?.id;
    if (!userId) throw new Error('Sesión no disponible');

    const payload = this.toDbPayload(input);
    await this.ensureHermandadTopicId(payload, input);
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .insert({
        ...payload,
        created_by: userId,
        status: input.status ?? 'published',
      })
      .select(EVENT_SELECT)
      .single();
    if (error) throw error;
    return this.mapRow(data as Record<string, unknown>);
  }

  async updateEvent(eventId: string, input: CalendarEventInput): Promise<CalendarEventRow> {
    const payload = this.toDbPayload(input);
    await this.ensureHermandadTopicId(payload, input, { keepExisting: true });
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .update({
        ...payload,
        ...(input.status ? { status: input.status } : {}),
        updated_at: new Date().toISOString(),
      })
      .eq('id', eventId)
      .select(EVENT_SELECT)
      .single();
    if (error) throw error;
    return this.mapRow(data as Record<string, unknown>);
  }

  async publishEvent(eventId: string): Promise<void> {
    const { error } = await getSupabase()
      .from('calendar_events')
      .update({ status: 'published', updated_at: new Date().toISOString() })
      .eq('id', eventId);
    if (error) throw error;
  }

  async deleteEvent(eventId: string): Promise<void> {
    const { error } = await getSupabase().from('calendar_events').delete().eq('id', eventId);
    if (error) throw error;
  }

  async uploadCover(file: File): Promise<string> {
    return this.uploadAsset(file, 'event-covers', 3 * 1024 * 1024);
  }

  async uploadIcon(file: File): Promise<string> {
    return this.uploadAsset(file, 'event-icons', 1 * 1024 * 1024);
  }

  /** Biblioteca de escudos (misma tabla que la app). */
  async searchOrganizerLogos(rawQuery = '', limit = 40): Promise<OrganizerLogo[]> {
    const query = rawQuery.replace(/[%_]/g, '').trim();
    let req = getSupabase()
      .from('organizer_logos')
      .select('organizer_key, display_label, logo_url')
      .order('display_label', { ascending: true })
      .limit(limit);

    if (query) {
      req = req.or(
        `display_label.ilike.%${query}%,organizer_key.ilike.%${query}%`,
      );
    }

    const { data, error } = await req;
    if (error) throw error;
    return (data ?? []).map((row) => ({
      organizerKey: String(row['organizer_key'] ?? ''),
      displayLabel: String(row['display_label'] ?? '').trim(),
      logoUrl: String(row['logo_url'] ?? '').trim(),
    }));
  }

  /** Guarda/actualiza escudo en biblioteca al publicar (como la app). */
  async saveOrganizerLogo(organizerLabel: string, logoUrl: string): Promise<void> {
    const userId = this.auth.user()?.id;
    if (!userId) return;
    const label = organizerLabel.trim();
    const url = logoUrl.trim();
    if (label.length < 3 || !url) return;

    const { error } = await getSupabase().from('organizer_logos').upsert(
      {
        organizer_key: normalizeOrganizerKey(label),
        display_label: label,
        logo_url: url,
        updated_by: userId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'organizer_key' },
    );
    if (error) throw error;
  }

  async deleteOrganizerLogo(organizerKey: string): Promise<void> {
    const key = organizerKey.trim();
    if (!key) return;
    const { error } = await getSupabase()
      .from('organizer_logos')
      .delete()
      .eq('organizer_key', key);
    if (error) throw error;
  }

  eventTypes() {
    return CALENDAR_EVENT_TYPES;
  }

  private async uploadAsset(
    file: File,
    bucket: 'event-covers' | 'event-icons',
    maxBytes: number,
  ): Promise<string> {
    const userId = this.auth.user()?.id;
    if (!userId) throw new Error('Sesión no disponible');
    if (file.size > maxBytes) {
      throw new Error(
        bucket === 'event-covers'
          ? 'La portada no puede superar 3 MB.'
          : 'El icono no puede superar 1 MB.',
      );
    }

    const ext = (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '');
    const path = `${userId}/${Date.now()}.${ext || 'jpg'}`;
    const { error } = await getSupabase().storage.from(bucket).upload(path, file, {
      upsert: true,
      contentType: file.type || 'image/jpeg',
    });
    if (error) throw error;
    const publicUrl = getSupabase().storage.from(bucket).getPublicUrl(path).data.publicUrl;
    return `${publicUrl}?v=${Date.now()}`;
  }

  private toDbPayload(input: CalendarEventInput): Record<string, unknown> {
    const type = input.eventType;
    const endsAt =
      input.endsAt === undefined
        ? undefined
        : input.endsAt
          ? new Date(input.endsAt).toISOString()
          : null;
    const isEnsayo = type === 'ensayo';
    const isMuda = type === 'muda';
    const seasonLabel = seasonActDayLabel({
      eventType: type,
      paso: input.paso,
      seasonN: isEnsayo ? input.seasonN : null,
      withRetranqueo: isMuda && input.withRetranqueo,
    });
    return {
      title: input.title.trim(),
      subtitle: input.subtitle.trim(),
      event_type: type,
      starts_at: new Date(input.startsAt).toISOString(),
      ...(endsAt !== undefined ? { ends_at: endsAt } : {}),
      span_until:
        type === 'besamanos' || type === 'besapies'
          ? input.spanUntil?.trim() || null
          : null,
      day_label: (
        input.dayLabel?.trim() ||
        seasonLabel ||
        eventTypeCellLabel(type)
      ).trim(),
      location: (input.location ?? '').trim(),
      admission_label: emptyToNull(input.admissionLabel),
      time_slots: normalizeSlots(input.timeSlots),
      organizer_label: (input.organizerLabel ?? '').trim(),
      custom_icon_url: (input.customIconUrl ?? '').trim(),
      cover_image_url: (input.coverImageUrl ?? '').trim(),
      cover_image_credit: emptyToNull(input.coverImageCredit),
      paso: input.paso ?? 'ambos',
      season_n: isEnsayo ? (input.seasonN ?? 1) : null,
      with_retranqueo: isMuda && input.withRetranqueo === true,
      ...(input.hermandadTopicId !== undefined
        ? { hermandad_topic_id: input.hermandadTopicId?.trim() || null }
        : {}),
    };
  }

  async resolveHermandadTopicId(organizerLabel: string): Promise<string | null> {
    const label = organizerLabel.trim();
    if (label.length < 3) return null;
    const { data, error } = await getSupabase()
      .from('forum_topics')
      .select('id, title')
      .eq('forum_id', 'hermandades')
      .eq('status', 'published')
      .limit(400);
    if (error || !data?.length) return null;
    let bestId: string | null = null;
    let bestScore = 0;
    for (const row of data) {
      const title = String(row['title'] ?? '');
      const parsed = parseHermandadTopicTitle(title);
      const name = parsed.hermandadName.trim() || title.trim();
      const score = Math.max(
        organizerMatchScore(label, name),
        organizerMatchScore(label, title),
      );
      if (score > bestScore) {
        bestScore = score;
        bestId = String(row['id'] ?? '') || null;
      }
    }
    return bestScore > 0 ? bestId : null;
  }

  private async ensureHermandadTopicId(
    payload: Record<string, unknown>,
    input: CalendarEventInput,
    opts: { keepExisting?: boolean } = {},
  ): Promise<void> {
    const organizer = (input.organizerLabel ?? '').trim();
    if (!organizer) {
      payload['hermandad_topic_id'] = null;
      return;
    }
    if (payload['hermandad_topic_id']) return;
    const resolved = await this.resolveHermandadTopicId(organizer);
    if (resolved) {
      payload['hermandad_topic_id'] = resolved;
      return;
    }
    if (opts.keepExisting) {
      delete payload['hermandad_topic_id'];
    }
  }

  async setLiveForceState(
    eventId: string,
    forceState: 'auto' | 'open' | 'closed',
  ): Promise<void> {
    const rpc = await getSupabase().rpc('admin_set_event_live_force_state', {
      p_event_id: eventId,
      p_force_state: forceState,
    });
    if (!rpc.error) return;

    const { error } = await getSupabase()
      .from('calendar_events')
      .update({
        live_force_state: forceState,
        updated_at: new Date().toISOString(),
      })
      .eq('id', eventId);
    if (error) throw error;
  }

  private mapRow(row: Record<string, unknown>): CalendarEventRow {
    const profiles = row['profiles'] as { handle?: string } | null;
    const typeRaw = String(row['event_type'] ?? 'evento');
    const eventType = (
      CALENDAR_EVENT_TYPES.some((t) => t.value === typeRaw) ? typeRaw : 'evento'
    ) as CalendarEventType;
    const statusRaw = String(row['status'] ?? 'published');
    const status = (
      ['published', 'pending_review', 'rejected'].includes(statusRaw)
        ? statusRaw
        : 'published'
    ) as CalendarEventStatus;
    const forceRaw = String(row['live_force_state'] ?? 'auto');
    const liveForceState = (
      ['auto', 'open', 'closed'].includes(forceRaw) ? forceRaw : 'auto'
    ) as EventLiveForceState;

    return {
      id: String(row['id'] ?? ''),
      title: String(row['title'] ?? ''),
      subtitle: String(row['subtitle'] ?? ''),
      eventType,
      startsAt: String(row['starts_at'] ?? ''),
      endsAt: (row['ends_at'] as string | null) ?? null,
      spanUntil: (row['span_until'] as string | null) ?? null,
      liveForceState,
      dayLabel: (row['day_label'] as string | null) ?? null,
      location: emptyToNull(row['location'] as string | null),
      admissionLabel: emptyToNull(row['admission_label'] as string | null),
      timeSlots: parseTimeSlots(row['time_slots']),
      organizerLabel: emptyToNull(row['organizer_label'] as string | null),
      customIconUrl: emptyToNull(row['custom_icon_url'] as string | null),
      coverImageUrl: emptyToNull(row['cover_image_url'] as string | null),
      coverImageCredit: emptyToNull(row['cover_image_credit'] as string | null),
      status,
      createdBy: (row['created_by'] as string | null) ?? null,
      createdByHandle: profiles?.handle ?? null,
      createdAt: String(row['created_at'] ?? ''),
      updatedAt: (row['updated_at'] as string | null) ?? null,
      paso: parsePaso(row['paso']),
      seasonN: (row['season_n'] as number | null) ?? null,
      withRetranqueo: row['with_retranqueo'] === true,
    };
  }

  async fetchShowBoardLink(): Promise<boolean> {
    const { data, error } = await getSupabase()
      .from('app_config')
      .select('value')
      .eq('key', CALENDAR_SHOW_BOARD_LINK_KEY)
      .maybeSingle();
    if (error) throw error;
    return String(data?.['value'] ?? '').trim() === 'on';
  }

  async setShowBoardLink(enabled: boolean): Promise<void> {
    const { error } = await getSupabase().from('app_config').upsert({
      key: CALENDAR_SHOW_BOARD_LINK_KEY,
      value: enabled ? 'on' : 'off',
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
  }
}

function normalizeSlots(
  slots: { start: string; end?: string | null }[] | null | undefined,
): { start: string; end?: string }[] | null {
  const list = parseTimeSlots(slots ?? []);
  const hasRange = list.some((slot) => !!slot.end);
  if (list.length < 2 && !hasRange) return null;
  return list.map((slot) =>
    slot.end ? { start: slot.start, end: slot.end } : { start: slot.start },
  );
}

function emptyToNull(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed) return null;
  return trimmed;
}

function parsePaso(raw: unknown): SeasonPaso {
  return raw === 'cristo' || raw === 'cristo2' || raw === 'virgen' ? raw : 'ambos';
}

function startOfLocalDayIso(): string {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return start.toISOString();
}

function normalizeOrganizerKey(raw: string): string {
  return raw
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/\.+/g, '.');
}
