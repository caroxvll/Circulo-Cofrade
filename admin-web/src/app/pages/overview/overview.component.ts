import { Component, OnInit, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { ModerationService } from '../../core/moderation/moderation.service';
import { visibleModules } from '../../core/nav/junta-modules';

@Component({
  selector: 'app-overview',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './overview.component.html',
  styleUrl: './overview.component.scss',
})
export class OverviewComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly moderation = inject(ModerationService);

  readonly profile = this.auth.profile;
  readonly isAdmin = this.auth.isAdmin;
  readonly counts = this.moderation.counts;
  readonly countsLoading = this.moderation.countsLoading;

  readonly modules = computed(() =>
    visibleModules(this.auth.isAdmin()).filter((m) => m.id !== 'overview'),
  );

  readonly queueCards = computed(() => {
    const c = this.counts();
    const cards = [
      {
        label: 'Temas pendientes',
        count: c.topics,
        route: '/app/temas',
      },
      {
        label: 'Reportes',
        count: c.reports,
        route: '/app/reportes',
      },
      {
        label: 'Cierres solicitados',
        count: c.closeRequests,
        route: '/app/cierres',
      },
    ];
    if (this.isAdmin()) {
      cards.splice(2, 0, {
        label: 'Eventos pendientes',
        count: c.events,
        route: '/app/eventos?tab=pending',
      });
    }
    return cards;
  });

  readonly pendingTotal = computed(() => {
    const c = this.counts();
    return c.topics + c.reports + c.closeRequests + (this.isAdmin() ? c.events : 0);
  });

  ngOnInit(): void {
    void this.moderation.refreshCounts();
  }

  refresh(): void {
    void this.moderation.refreshCounts();
  }
}
