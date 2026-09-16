import {
  Component,
  EventEmitter,
  Output,
  forwardRef,
  signal,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR, FormsModule } from '@angular/forms';
import { CommunityService, HandleHit } from '../core/community/community.service';
import { inject } from '@angular/core';

@Component({
  selector: 'app-handle-search',
  standalone: true,
  imports: [FormsModule],
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => HandleSearchComponent),
      multi: true,
    },
  ],
  template: `
    <div class="handle-search">
      <input
        type="search"
        [ngModel]="query()"
        (ngModelChange)="onQuery($event)"
        placeholder="Buscar @handle…"
        autocomplete="off"
      />
      @if (hits().length) {
        <ul>
          @for (hit of hits(); track hit.id) {
            <li>
              <button type="button" (click)="pick(hit)">
                <strong>{{ '@' + hit.handle }}</strong>
                <span>{{ hit.displayName }}</span>
              </button>
            </li>
          }
        </ul>
      }
    </div>
  `,
  styles: [
    `
      .handle-search {
        position: relative;
      }
      input {
        width: 100%;
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 10px 12px;
        font: inherit;
        background: #fff;
      }
      ul {
        position: absolute;
        z-index: 5;
        left: 0;
        right: 0;
        margin: 4px 0 0;
        padding: 6px;
        list-style: none;
        background: #fff;
        border: 1px solid var(--border);
        border-radius: 10px;
        box-shadow: var(--shadow-md);
        max-height: 220px;
        overflow: auto;
      }
      button {
        width: 100%;
        text-align: left;
        border: 0;
        background: transparent;
        padding: 8px 10px;
        border-radius: 8px;
        cursor: pointer;
        display: grid;
        gap: 2px;
      }
      button:hover {
        background: #f5efe8;
      }
      span {
        color: var(--text-muted);
        font-size: 0.85rem;
      }
    `,
  ],
})
export class HandleSearchComponent implements ControlValueAccessor {
  private readonly community = inject(CommunityService);
  private timer: ReturnType<typeof setTimeout> | null = null;

  readonly query = signal('');
  readonly hits = signal<HandleHit[]>([]);
  readonly selected = signal<HandleHit | null>(null);

  @Output() readonly picked = new EventEmitter<HandleHit>();

  private onChange: (value: HandleHit | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  writeValue(value: HandleHit | null): void {
    this.selected.set(value);
    this.query.set(value ? `@${value.handle}` : '');
  }

  registerOnChange(fn: (value: HandleHit | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  onQuery(value: string): void {
    this.query.set(value);
    this.selected.set(null);
    this.onChange(null);
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => void this.search(value), 280);
  }

  private async search(value: string): Promise<void> {
    try {
      this.hits.set(await this.community.searchHandles(value));
    } catch {
      this.hits.set([]);
    }
  }

  pick(hit: HandleHit): void {
    this.selected.set(hit);
    this.query.set(`@${hit.handle}`);
    this.hits.set([]);
    this.onChange(hit);
    this.onTouched();
    this.picked.emit(hit);
  }
}
