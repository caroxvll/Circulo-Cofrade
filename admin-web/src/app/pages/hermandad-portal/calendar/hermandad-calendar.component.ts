import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';
import {
  CALENDAR_EVENT_TYPES,
  CalendarEventType,
  CalendarTimeSlot,
  eventTypeLabel,
  scheduleLabel,
} from '../../../core/events/events.models';
import { HermandadPortalService } from '../../../core/hermandad/hermandad-portal.service';
import {
  HermandadPortalStore,
  HermandadUpcomingEvent,
} from '../../../core/hermandad/hermandad-portal.store';
import { ConfirmDialogService } from '../../../shared/confirm-dialog/confirm-dialog.service';

interface CalDay {
  key: string;
  day: number;
  inMonth: boolean;
  isToday: boolean;
  events: HermandadUpcomingEvent[];
}

const WEEKDAYS = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'] as const;

function dateKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function startOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

function addMonths(d: Date, delta: number): Date {
  return new Date(d.getFullYear(), d.getMonth() + delta, 1);
}

function toLocalParts(iso: string): { date: string; time: string } {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return { date: '', time: '' };
  const pad = (n: number) => String(n).padStart(2, '0');
  return {
    date: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`,
    time: `${pad(d.getHours())}:${pad(d.getMinutes())}`,
  };
}

function fromLocalParts(date: string, time: string): string | null {
  const d = (date || '').trim();
  const t = (time || '').trim() || '00:00';
  if (!d) return null;
  const iso = new Date(`${d}T${t}`).toISOString();
  return Number.isNaN(Date.parse(iso)) ? null : iso;
}

@Component({
  selector: 'app-hermandad-calendar-page',
  standalone: true,
  imports: [RouterLink, FormsModule],
  templateUrl: './hermandad-calendar.component.html',
  styleUrl: './hermandad-calendar.component.scss',
})
export class HermandadCalendarPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly api = inject(HermandadPortalService);
  private readonly store = inject(HermandadPortalStore);
  private readonly confirm = inject(ConfirmDialogService);

  readonly weekdays = WEEKDAYS;
  readonly eventTypes = CALENDAR_EVENT_TYPES;
  readonly eventTypeLabel = eventTypeLabel;

  readonly cursor = signal(startOfMonth(new Date()));
  readonly selectedKey = signal(dateKey(new Date()));
  readonly events = signal<HermandadUpcomingEvent[]>([]);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  /** Evento abierto en la ficha lateral. */
  readonly activeEvent = signal<HermandadUpcomingEvent | null>(null);
  readonly editTitle = signal('');
  readonly editDate = signal('');
  readonly editTime = signal('');
  readonly editLocation = signal('');
  readonly editAdmission = signal('');
  readonly editFirstEnd = signal('');
  readonly editExtraSlots = signal<{ start: string; end: string }[]>([]);
  readonly editType = signal<CalendarEventType>('evento');
  readonly saving = signal(false);
  readonly saveError = signal<string | null>(null);

  readonly monthLabel = computed(() => {
    const d = this.cursor();
    const label = d.toLocaleDateString('es-ES', {
      month: 'long',
      year: 'numeric',
    });
    return label.charAt(0).toUpperCase() + label.slice(1);
  });

  readonly days = computed((): CalDay[] => {
    const cursor = this.cursor();
    const todayKey = dateKey(new Date());
    const byDay = new Map<string, HermandadUpcomingEvent[]>();
    for (const ev of this.events()) {
      const key = dateKey(new Date(ev.startsAt));
      const list = byDay.get(key) ?? [];
      list.push(ev);
      byDay.set(key, list);
    }

    const first = startOfMonth(cursor);
    const mondayOffset = (first.getDay() + 6) % 7;
    const gridStart = new Date(first);
    gridStart.setDate(first.getDate() - mondayOffset);

    const cells: CalDay[] = [];
    for (let i = 0; i < 42; i++) {
      const d = new Date(gridStart);
      d.setDate(gridStart.getDate() + i);
      const key = dateKey(d);
      cells.push({
        key,
        day: d.getDate(),
        inMonth: d.getMonth() === cursor.getMonth(),
        isToday: key === todayKey,
        events: byDay.get(key) ?? [],
      });
    }
    return cells;
  });

  readonly selectedEvents = computed(() => {
    const key = this.selectedKey();
    return this.events()
      .filter((ev) => dateKey(new Date(ev.startsAt)) === key)
      .sort((a, b) => a.startsAt.localeCompare(b.startsAt));
  });

  readonly selectedLabel = computed(() => {
    const [y, m, d] = this.selectedKey().split('-').map(Number);
    const date = new Date(y, m - 1, d);
    return date.toLocaleDateString('es-ES', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    });
  });

  readonly monthEventCount = computed(() => {
    const cursor = this.cursor();
    return this.events().filter((ev) => {
      const d = new Date(ev.startsAt);
      return (
        d.getMonth() === cursor.getMonth() &&
        d.getFullYear() === cursor.getFullYear()
      );
    }).length;
  });

  readonly detailDirty = computed(() => {
    const ev = this.activeEvent();
    if (!ev) return false;
    const parts = toLocalParts(ev.startsAt);
    return (
      this.editTitle().trim() !== ev.title.trim() ||
      this.editDate() !== parts.date ||
      this.editTime() !== parts.time ||
      (this.editLocation().trim() || '') !== (ev.location?.trim() || '') ||
      (this.editAdmission().trim() || '') !== (ev.admissionLabel?.trim() || '') ||
      this.editFirstEnd() !== (ev.timeSlots[0]?.end ?? '') ||
      JSON.stringify(this.editExtraSlots()) !==
        JSON.stringify(
          ev.timeSlots.slice(1).map((slot) => ({
            start: slot.start,
            end: slot.end ?? '',
          })),
        ) ||
      this.editType() !== ev.eventType
    );
  });

  ngOnInit(): void {
    void this.store.ensureLoaded().then(() => this.loadMonth());
  }

  shiftMonth(delta: number): void {
    this.closeDetail();
    this.cursor.set(addMonths(this.cursor(), delta));
    void this.loadMonth();
  }

  goToday(): void {
    this.closeDetail();
    const now = new Date();
    this.cursor.set(startOfMonth(now));
    this.selectedKey.set(dateKey(now));
    void this.loadMonth();
  }

  selectDay(day: CalDay): void {
    this.selectedKey.set(day.key);
    this.closeDetail();
    if (!day.inMonth) {
      const [y, m] = day.key.split('-').map(Number);
      this.cursor.set(new Date(y, m - 1, 1));
      void this.loadMonth();
    }
  }

  /** Atajo: pulsar un evento en la celda o en la lista. */
  openEvent(ev: HermandadUpcomingEvent, event?: Event): void {
    event?.stopPropagation();
    this.selectedKey.set(dateKey(new Date(ev.startsAt)));
    this.activeEvent.set(ev);
    this.editTitle.set(ev.title);
    const parts = toLocalParts(ev.startsAt);
    this.editDate.set(parts.date);
    this.editTime.set(parts.time);
    this.editLocation.set(ev.location ?? '');
    this.editAdmission.set(ev.admissionLabel ?? '');
    this.editFirstEnd.set(ev.timeSlots[0]?.end ?? '');
    this.editExtraSlots.set(
      ev.timeSlots.slice(1).map((slot) => ({
        start: slot.start,
        end: slot.end ?? '',
      })),
    );
    this.editType.set(
      (CALENDAR_EVENT_TYPES.some((t) => t.value === ev.eventType)
        ? ev.eventType
        : 'evento') as CalendarEventType,
    );
    this.saveError.set(null);
  }

  slotsOf(ev: HermandadUpcomingEvent): string | null {
    return scheduleLabel(ev.timeSlots);
  }

  addExtraSlot(): void {
    if (this.editExtraSlots().length >= 5) return;
    this.editExtraSlots.update((list) => [...list, { start: '19:00', end: '' }]);
  }

  removeExtraSlot(index: number): void {
    this.editExtraSlots.update((list) => list.filter((_, i) => i !== index));
  }

  updateExtraSlot(index: number, patch: { start?: string; end?: string }): void {
    this.editExtraSlots.update((list) =>
      list.map((slot, i) => (i === index ? { ...slot, ...patch } : slot)),
    );
  }

  private slotsFromForm(): CalendarTimeSlot[] {
    const slots: CalendarTimeSlot[] = [
      {
        start: this.editTime().trim() || '00:00',
        end: this.editFirstEnd().trim() || null,
      },
      ...this.editExtraSlots()
        .filter((slot) => /^\d{2}:\d{2}$/.test(slot.start.trim()))
        .map((slot) => ({
          start: slot.start.trim(),
          end: slot.end.trim() || null,
        })),
    ];
    return slots;
  }

  closeDetail(): void {
    this.activeEvent.set(null);
    this.saveError.set(null);
  }

  formatTime(iso: string): string {
    return new Date(iso).toLocaleTimeString('es-ES', {
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  formatFullDate(iso: string): string {
    return new Date(iso).toLocaleDateString('es-ES', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  }

  async saveEvent(): Promise<void> {
    const ev = this.activeEvent();
    if (!ev) return;
    const title = this.editTitle().trim();
    if (title.length < 2) {
      this.saveError.set('Indica un título.');
      return;
    }
    const startsAtIso = fromLocalParts(this.editDate(), this.editTime());
    if (!startsAtIso) {
      this.saveError.set('Indica una fecha y hora válidas.');
      return;
    }

    this.saving.set(true);
    this.saveError.set(null);
    try {
      const updated = await this.store.updateUpcomingEvent(ev.id, {
        title,
        startsAtIso,
        location: this.editLocation().trim() || null,
        eventType: this.editType(),
        admissionLabel: this.editAdmission().trim() || null,
        timeSlots: this.slotsFromForm(),
      });
      this.events.update((list) =>
        list.map((e) =>
          e.id === ev.id
            ? {
                ...e,
                title: updated.title,
                startsAt: updated.startsAt,
                location: updated.location,
                eventType: updated.eventType,
                admissionLabel: updated.admissionLabel,
                timeSlots: updated.timeSlots,
              }
            : e,
        ),
      );
      this.activeEvent.set({
        ...ev,
        title: updated.title,
        startsAt: updated.startsAt,
        location: updated.location,
        eventType: updated.eventType,
        admissionLabel: updated.admissionLabel,
        timeSlots: updated.timeSlots,
      });
      const parts = toLocalParts(updated.startsAt);
      this.editDate.set(parts.date);
      this.editTime.set(parts.time);
      this.selectedKey.set(dateKey(new Date(updated.startsAt)));
    } catch (err) {
      this.saveError.set(
        err instanceof Error ? err.message : 'No se pudo guardar el evento',
      );
    } finally {
      this.saving.set(false);
    }
  }

  async deleteEvent(ev: HermandadUpcomingEvent, event?: Event): Promise<void> {
    event?.stopPropagation();
    const ok = await this.confirm.confirm({
      title: 'Quitar del calendario',
      message: `Se eliminará «${ev.title}» del calendario.\nDejará de verse en la app.`,
      confirmLabel: 'Quitar',
      cancelLabel: 'Cancelar',
      tone: 'danger',
    });
    if (!ok) return;
    try {
      await this.store.deleteUpcomingEvent(ev.id);
      this.events.update((list) => list.filter((e) => e.id !== ev.id));
      if (this.activeEvent()?.id === ev.id) this.closeDetail();
    } catch (err) {
      console.error(err);
      await this.confirm.alert({
        title: 'No se pudo quitar',
        message: 'No se pudo quitar el evento. Inténtalo de nuevo.',
      });
    }
  }

  private async loadMonth(): Promise<void> {
    const profile = this.auth.profile();
    if (!profile) return;

    const cursor = this.cursor();
    const from = new Date(cursor.getFullYear(), cursor.getMonth(), 1);
    from.setDate(from.getDate() - 7);
    const to = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
    to.setDate(to.getDate() + 7);

    this.loading.set(true);
    this.error.set(null);
    try {
      const list = await this.api.fetchOwnEventsInRange(
        profile.id,
        from.toISOString(),
        to.toISOString(),
      );
      this.events.set(list);
      const open = this.activeEvent();
      if (open) {
        const fresh = list.find((e) => e.id === open.id) ?? null;
        if (fresh) this.openEvent(fresh);
        else this.closeDetail();
      }
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo cargar el calendario',
      );
      this.events.set([]);
    } finally {
      this.loading.set(false);
    }
  }
}
