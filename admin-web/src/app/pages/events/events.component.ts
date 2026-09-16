import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import {
  CALENDAR_EVENT_TYPES,
  CalendarEventRow,
  CalendarEventType,
  OrganizerLogo,
  eventTypeLabel,
} from '../../core/events/events.models';
import { EventsService } from '../../core/events/events.service';
import { ModerationService } from '../../core/moderation/moderation.service';
import { formatDateTime, formatTimeAgo } from '../../core/utils/date';

type EventsTab = 'calendar' | 'pending';
type EventsRange = 'upcoming' | 'past' | 'all';

@Component({
  selector: 'app-events-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './events.component.html',
  styleUrl: './events.component.scss',
})
export class EventsPageComponent implements OnInit {
  private readonly eventsApi = inject(EventsService);
  private readonly moderation = inject(ModerationService);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  readonly tab = signal<EventsTab>('calendar');
  readonly range = signal<EventsRange>('upcoming');
  readonly typeFilter = signal<CalendarEventType | 'all'>('all');
  readonly events = signal<CalendarEventRow[]>([]);
  readonly pending = signal<CalendarEventRow[]>([]);
  readonly pendingCount = signal(0);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly uploading = signal(false);
  readonly error = signal<string | null>(null);
  readonly busyId = signal<string | null>(null);
  readonly showForm = signal(false);
  readonly editing = signal<CalendarEventRow | null>(null);
  readonly organizers = signal<OrganizerLogo[]>([]);
  readonly organizersLoading = signal(false);
  readonly selectedOrganizerKey = signal<string | null>(null);

  search = '';
  organizerSearch = '';
  formTitle = '';
  formSubtitle = '';
  formType: CalendarEventType = 'evento';
  formLocation = '';
  formOrganizer = '';
  formStartsAtLocal = '';
  formCoverUrl = '';
  formIconUrl = '';

  readonly eventTypes = CALENDAR_EVENT_TYPES;
  readonly typeLabel = eventTypeLabel;
  readonly timeAgo = formatTimeAgo;
  readonly dateTime = formatDateTime;

  readonly formTitleText = computed(() =>
    this.editing() ? 'Editar evento' : 'Nuevo evento',
  );

  ngOnInit(): void {
    if (!this.auth.isAdmin()) {
      void this.router.navigateByUrl('/app/resumen');
      return;
    }
    const tab = this.route.snapshot.queryParamMap.get('tab');
    if (tab === 'pending') {
      this.tab.set('pending');
    }
    void this.reload();
  }

  setTab(tab: EventsTab): void {
    this.tab.set(tab);
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: tab === 'pending' ? { tab: 'pending' } : {},
      replaceUrl: true,
    });
  }

  setRange(range: EventsRange): void {
    this.range.set(range);
    void this.reloadCalendar();
  }

  setTypeFilter(value: CalendarEventType | 'all'): void {
    this.typeFilter.set(value);
    void this.reloadCalendar();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      await Promise.all([this.reloadCalendar(), this.reloadPending()]);
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cargar');
    } finally {
      this.loading.set(false);
    }
  }

  async reloadCalendar(): Promise<void> {
    const rows = await this.eventsApi.listEvents({
      status: 'published',
      range: this.range(),
      eventType: this.typeFilter(),
      search: this.search,
      limit: 150,
    });
    this.events.set(rows);
  }

  async reloadPending(): Promise<void> {
    const rows = await this.eventsApi.listEvents({
      status: 'pending_review',
      range: 'all',
      limit: 80,
    });
    this.pending.set(rows);
    this.pendingCount.set(rows.length);
  }

  searchCalendar(): void {
    void this.reloadCalendar();
  }

  openCreate(): void {
    this.editing.set(null);
    this.resetFormFields();
    this.formStartsAtLocal = toDatetimeLocalValue(
      new Date(Date.now() + 60 * 60 * 1000),
    );
    this.showForm.set(true);
    void this.reloadOrganizers();
  }

  openEdit(event: CalendarEventRow): void {
    this.editing.set(event);
    this.resetFormFields();
    this.formTitle = event.title;
    this.formSubtitle = event.subtitle;
    this.formType = event.eventType;
    this.formLocation = event.location ?? '';
    this.formOrganizer = event.organizerLabel ?? '';
    this.formStartsAtLocal = toDatetimeLocalValue(new Date(event.startsAt));
    this.formCoverUrl = event.coverImageUrl ?? '';
    this.formIconUrl = event.customIconUrl ?? '';
    this.showForm.set(true);
    void this.reloadOrganizers(event.organizerLabel ?? '');
  }

  closeForm(): void {
    if (this.saving() || this.uploading()) return;
    this.showForm.set(false);
    this.editing.set(null);
    this.selectedOrganizerKey.set(null);
    this.organizerSearch = '';
  }

  async reloadOrganizers(seedQuery = ''): Promise<void> {
    this.organizersLoading.set(true);
    try {
      const q = this.organizerSearch.trim() || seedQuery.trim();
      this.organizers.set(await this.eventsApi.searchOrganizerLogos(q, 50));
      this.syncSelectedOrganizerKey();
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo cargar la biblioteca',
      );
    } finally {
      this.organizersLoading.set(false);
    }
  }

  searchOrganizers(): void {
    void this.reloadOrganizers();
  }

  pickOrganizer(item: OrganizerLogo): void {
    this.formOrganizer = item.displayLabel || item.organizerKey;
    if (item.logoUrl) {
      this.formIconUrl = item.logoUrl;
    }
    this.selectedOrganizerKey.set(item.organizerKey);
  }

  async removeOrganizerFromLibrary(
    event: MouseEvent,
    item: OrganizerLogo,
  ): Promise<void> {
    event.preventDefault();
    event.stopPropagation();
    const name = item.displayLabel || item.organizerKey;
    if (!confirm(`¿Eliminar «${name}» de la biblioteca de escudos?`)) return;

    this.busyId.set(item.organizerKey);
    this.error.set(null);
    try {
      await this.eventsApi.deleteOrganizerLogo(item.organizerKey);
      if (this.selectedOrganizerKey() === item.organizerKey) {
        this.selectedOrganizerKey.set(null);
      }
      await this.reloadOrganizers();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar');
    } finally {
      this.busyId.set(null);
    }
  }

  onOrganizerTyped(): void {
    this.syncSelectedOrganizerKey();
  }

  private resetFormFields(): void {
    this.formTitle = '';
    this.formSubtitle = '';
    this.formType = 'evento';
    this.formLocation = '';
    this.formOrganizer = '';
    this.formCoverUrl = '';
    this.formIconUrl = '';
    this.organizerSearch = '';
    this.selectedOrganizerKey.set(null);
  }

  private syncSelectedOrganizerKey(): void {
    const label = this.formOrganizer.trim().toLowerCase();
    if (!label) {
      this.selectedOrganizerKey.set(null);
      return;
    }
    const hit = this.organizers().find(
      (o) =>
        o.displayLabel.trim().toLowerCase() === label ||
        o.organizerKey === label,
    );
    this.selectedOrganizerKey.set(hit?.organizerKey ?? null);
  }

  async saveForm(): Promise<void> {
    const title = this.formTitle.trim();
    if (title.length < 3) {
      this.error.set('El título debe tener al menos 3 caracteres.');
      return;
    }
    if (!this.formStartsAtLocal) {
      this.error.set('Indica fecha y hora del evento.');
      return;
    }

    this.saving.set(true);
    this.error.set(null);
    try {
      const organizerLabel = this.formOrganizer.trim();
      let customIconUrl = this.formIconUrl.trim();
      const coverImageUrl = this.formCoverUrl.trim();

      // Si no hay escudo, intenta el de la biblioteca o la portada.
      if (!customIconUrl && organizerLabel) {
        const fromLib = this.organizers().find(
          (o) =>
            o.displayLabel.trim().toLowerCase() === organizerLabel.toLowerCase() ||
            o.organizerKey === organizerLabel.toLowerCase(),
        );
        if (fromLib?.logoUrl) {
          customIconUrl = fromLib.logoUrl.trim();
          this.formIconUrl = customIconUrl;
        }
      }
      if (!customIconUrl && coverImageUrl) {
        customIconUrl = coverImageUrl;
        this.formIconUrl = customIconUrl;
      }

      const input = {
        title,
        subtitle: this.formSubtitle.trim(),
        eventType: this.formType,
        startsAt: fromDatetimeLocalValue(this.formStartsAtLocal),
        location: this.formLocation,
        organizerLabel,
        coverImageUrl,
        customIconUrl,
        status: 'published' as const,
      };
      const editing = this.editing();
      if (editing) {
        await this.eventsApi.updateEvent(editing.id, input);
      } else {
        await this.eventsApi.createEvent(input);
      }
      if (organizerLabel.length >= 3 && customIconUrl) {
        try {
          await this.eventsApi.saveOrganizerLogo(organizerLabel, customIconUrl);
        } catch (logoErr) {
          console.warn('No se pudo guardar el escudo en biblioteca', logoErr);
          this.error.set(
            'Evento guardado, pero el escudo no se pudo añadir a la biblioteca. Revisa permisos o vuelve a editar.',
          );
        }
      }
      this.showForm.set(false);
      this.editing.set(null);
      this.selectedOrganizerKey.set(null);
      this.tab.set('calendar');
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar');
    } finally {
      this.saving.set(false);
    }
  }

  async onUpload(kind: 'cover' | 'icon', event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;

    this.uploading.set(true);
    this.error.set(null);
    try {
      if (kind === 'cover') {
        this.formCoverUrl = await this.eventsApi.uploadCover(file);
      } else {
        this.formIconUrl = await this.eventsApi.uploadIcon(file);
      }
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo subir');
    } finally {
      this.uploading.set(false);
    }
  }

  clearCover(): void {
    this.formCoverUrl = '';
  }

  clearIcon(): void {
    this.formIconUrl = '';
  }

  async publish(event: CalendarEventRow): Promise<void> {
    this.busyId.set(event.id);
    this.error.set(null);
    try {
      await this.eventsApi.publishEvent(event.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo publicar');
    } finally {
      this.busyId.set(null);
    }
  }

  async reject(event: CalendarEventRow): Promise<void> {
    if (!confirm(`¿Rechazar y borrar «${event.title}»?`)) return;
    this.busyId.set(event.id);
    this.error.set(null);
    try {
      await this.eventsApi.deleteEvent(event.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo rechazar');
    } finally {
      this.busyId.set(null);
    }
  }

  async remove(event: CalendarEventRow): Promise<void> {
    if (!confirm(`¿Eliminar el evento publicado «${event.title}»?`)) return;
    this.busyId.set(event.id);
    this.error.set(null);
    try {
      await this.eventsApi.deleteEvent(event.id);
      await this.reloadCalendar();
      await this.moderation.refreshCounts();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar');
    } finally {
      this.busyId.set(null);
    }
  }
}

function toDatetimeLocalValue(date: Date): string {
  if (Number.isNaN(date.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function fromDatetimeLocalValue(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error('Fecha u hora no válida');
  }
  return date.toISOString();
}
