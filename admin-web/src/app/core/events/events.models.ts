export type CalendarEventStatus = 'published' | 'pending_review' | 'rejected';

export type CalendarEventType =
  | 'procesion'
  | 'gloria'
  | 'ensayo'
  | 'iguala'
  | 'concierto'
  | 'evento';

export interface CalendarEventRow {
  id: string;
  title: string;
  subtitle: string;
  eventType: CalendarEventType;
  startsAt: string;
  dayLabel: string | null;
  location: string | null;
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
  dayLabel?: string | null;
  location?: string | null;
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
    { value: 'evento', label: 'Eventos', cellLabel: 'Evento' },
  ];

export function eventTypeLabel(type: string | null | undefined): string {
  const hit = CALENDAR_EVENT_TYPES.find((t) => t.value === type);
  return hit?.label ?? type ?? 'Evento';
}

export function eventTypeCellLabel(type: CalendarEventType): string {
  return CALENDAR_EVENT_TYPES.find((t) => t.value === type)?.cellLabel ?? 'Evento';
}

/** Escudo de la biblioteca (misma tabla que la app). */
export interface OrganizerLogo {
  organizerKey: string;
  displayLabel: string;
  logoUrl: string;
}
