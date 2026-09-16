import { Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute } from '@angular/router';
import { map } from 'rxjs';
import { JUNTA_MODULES } from '../../core/nav/junta-modules';

@Component({
  selector: 'app-placeholder',
  standalone: true,
  templateUrl: './placeholder.component.html',
  styleUrl: './placeholder.component.scss',
})
export class PlaceholderComponent {
  private readonly route = inject(ActivatedRoute);

  readonly module = toSignal(
    this.route.data.pipe(
      map(
        (data) =>
          JUNTA_MODULES.find((m) => m.id === data['moduleId']) ?? null,
      ),
    ),
    { initialValue: null },
  );
}
