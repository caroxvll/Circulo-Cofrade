export type CalendarEventStatus = 'published' | 'pending_review' | 'rejected';

export type EventLiveForceState = 'auto' | 'open' | 'closed';

export type CalendarEventType =
  | 'procesion'
  | 'gloria'
  | 'ensayo'
  | 'iguala'
  | 'concierto'
  | 'culto'
  | 'besamanos'
  | 'quinario'
  | 'triduo'
  | 'pregon'
  | 'traslado'
  | 'muda'
  | 'retranqueo'
  | 'via_crucis'
  | 'via_crucis_consejo'
  | 'evento';

export interface CalendarEventRow {
  id: string;
  title: string;
  subtitle: string;
  eventType: CalendarEventType;
  startsAt: string;
  endsAt: string | null;
  liveForceState: EventLiveForceState;
  dayLabel: string | null;
  location: string | null;
  admissionLabel: string | null;
  timeSlots: CalendarTimeSlot[];
  organizerLabel: string | null;
  customIconUrl: string | null;
  coverImageUrl: string | null;
  status: CalendarEventStatus;
  createdBy: string | null;
  createdByHandle: string | null;
  createdAt: string;
  updatedAt: string | null;
}

export interface CalendarEventInput {
  title: string;
  subtitle: string;
  eventType: CalendarEventType;
  startsAt: string;
  endsAt?: string | null;
  dayLabel?: string | null;
  location?: string | null;
  admissionLabel?: string | null;
  timeSlots?: CalendarTimeSlot[] | null;
  organizerLabel?: string | null;
  customIconUrl?: string | null;
  coverImageUrl?: string | null;
  /** Solo en create: por defecto published (admin). */
  status?: CalendarEventStatus;
}

export interface CalendarEventListQuery {
  status?: CalendarEventStatus | 'all';
  eventType?: CalendarEventType | 'all';
  search?: string;
  /** upcoming = desde hoy; past = antes de hoy; all = sin filtro fecha */
  range?: 'upcoming' | 'past' | 'all';
  limit?: number;
}

export const CALENDAR_EVENT_TYPES: { value: CalendarEventType; label: string; cellLabel: string }[] =
  [
    { value: 'procesion', label: 'Procesiones', cellLabel: 'Procesión' },
    { value: 'gloria', label: 'Glorias', cellLabel: 'Gloria' },
    { value: 'ensayo', label: 'Ensayos', cellLabel: 'Ensayo' },
    { value: 'iguala', label: 'Igualás', cellLabel: 'Iguala' },
    { value: 'concierto', label: 'Conciertos', cellLabel: 'Concierto' },
    { value: 'culto', label: 'Cultos', cellLabel: 'Culto' },
    { value: 'besamanos', label: 'Besamanos', cellLabel: 'Besamanos' },
    { value: 'quinario', label: 'Quinarios', cellLabel: 'Quinario' },
    { value: 'triduo', label: 'Triduos', cellLabel: 'Triduo' },
    { value: 'pregon', label: 'Pregones', cellLabel: 'Pregón' },
    { value: 'traslado', label: 'Traslados', cellLabel: 'Traslado' },
    { value: 'muda', label: 'Mudas', cellLabel: 'Muda' },
    { value: 'retranqueo', label: 'Retranqueos', cellLabel: 'Retranqueo' },
    { value: 'via_crucis', label: 'Vía crucis', cellLabel: 'Vía crucis' },
    {
      value: 'via_crucis_consejo',
      label: 'Vía crucis del Consejo',
      cellLabel: 'Vía crucis del Consejo',
    },
    { value: 'evento', label: 'Eventos', cellLabel: 'Evento' },
  ];

export function eventTypeLabel(type: string | null | undefined): string {
  const hit = CALENDAR_EVENT_TYPES.find((t) => t.value === type);
  return hit?.label ?? type ?? 'Evento';
}

export function eventTypeCellLabel(type: CalendarEventType): string {
  return CALENDAR_EVENT_TYPES.find((t) => t.value === type)?.cellLabel ?? 'Evento';
}

/** Tramo del mismo día. `end` vacío = solo hora de inicio. */
export interface CalendarTimeSlot {
  start: string;
  end?: string | null;
}

const CLOCK = /^([01]\d|2[0-3]):[0-5]\d$/;

export function parseTimeSlots(raw: unknown): CalendarTimeSlot[] {
  if (!Array.isArray(raw)) return [];
  const slots: CalendarTimeSlot[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const row = item as { start?: unknown; end?: unknown };
    const start = String(row.start ?? '').trim();
    if (!CLOCK.test(start)) continue;
    const endRaw = String(row.end ?? '').trim();
    const end = CLOCK.test(endRaw) && endRaw > start ? endRaw : null;
    slots.push({ start, end });
    if (slots.length === 6) break;
  }
  slots.sort((a, b) => a.start.localeCompare(b.start));
  return slots;
}

export function slotLabel(slot: CalendarTimeSlot): string {
  return slot.end ? `${slot.start}–${slot.end} h` : `${slot.start} h`;
}

export function scheduleLabel(slots: CalendarTimeSlot[] | null | undefined): string | null {
  const list = slots ?? [];
  if (!list.length) return null;
  const hasRange = list.some((slot) => !!slot.end);
  if (list.length < 2 && !hasRange) return null;
  return list.map(slotLabel).join(' · ');
}

/** Escudo de la biblioteca (misma tabla que la app). */
export interface OrganizerLogo {
  organizerKey: string;
  displayLabel: string;
  logoUrl: string;
}
