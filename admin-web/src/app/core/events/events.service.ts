import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { getSupabase } from '../supabase.client';
import {
  CALENDAR_EVENT_TYPES,
  CalendarEventInput,
  CalendarEventListQuery,
  CalendarEventRow,
  CalendarEventStatus,
  CalendarEventType,
  OrganizerLogo,
  eventTypeCellLabel,
} from './events.models';

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
      .select(
        'id, title, subtitle, event_type, starts_at, day_label, location, organizer_label, custom_icon_url, cover_image_url, status, created_by, created_at, updated_at, profiles!created_by(handle)',
      )
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
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .insert({
        ...payload,
        created_by: userId,
        status: input.status ?? 'published',
      })
      .select(
        'id, title, subtitle, event_type, starts_at, day_label, location, organizer_label, custom_icon_url, cover_image_url, status, created_by, created_at, updated_at, profiles!created_by(handle)',
      )
      .single();
    if (error) throw error;
    return this.mapRow(data as Record<string, unknown>);
  }

  async updateEvent(eventId: string, input: CalendarEventInput): Promise<CalendarEventRow> {
    const payload = this.toDbPayload(input);
    const { data, error } = await getSupabase()
      .from('calendar_events')
      .update({
        ...payload,
        ...(input.status ? { status: input.status } : {}),
        updated_at: new Date().toISOString(),
      })
      .eq('id', eventId)
      .select(
        'id, title, subtitle, event_type, starts_at, day_label, location, organizer_label, custom_icon_url, cover_image_url, status, created_by, created_at, updated_at, profiles!created_by(handle)',
      )
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
    return {
      title: input.title.trim(),
      subtitle: input.subtitle.trim(),
      event_type: type,
      starts_at: new Date(input.startsAt).toISOString(),
      day_label: (input.dayLabel?.trim() || eventTypeCellLabel(type)).trim(),
      location: (input.location ?? '').trim(),
      organizer_label: (input.organizerLabel ?? '').trim(),
      custom_icon_url: (input.customIconUrl ?? '').trim(),
      cover_image_url: (input.coverImageUrl ?? '').trim(),
    };
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

    return {
      id: String(row['id'] ?? ''),
      title: String(row['title'] ?? ''),
      subtitle: String(row['subtitle'] ?? ''),
      eventType,
      startsAt: String(row['starts_at'] ?? ''),
      dayLabel: (row['day_label'] as string | null) ?? null,
      location: emptyToNull(row['location'] as string | null),
      organizerLabel: emptyToNull(row['organizer_label'] as string | null),
      customIconUrl: emptyToNull(row['custom_icon_url'] as string | null),
      coverImageUrl: emptyToNull(row['cover_image_url'] as string | null),
      status,
      createdBy: (row['created_by'] as string | null) ?? null,
      createdByHandle: profiles?.handle ?? null,
      createdAt: String(row['created_at'] ?? ''),
      updatedAt: (row['updated_at'] as string | null) ?? null,
    };
  }
}

function emptyToNull(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed) return null;
  return trimmed;
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
