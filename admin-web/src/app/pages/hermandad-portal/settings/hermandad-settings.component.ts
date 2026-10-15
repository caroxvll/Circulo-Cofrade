import { Component, OnInit, computed, effect, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../../core/auth/auth.service';
import { HermandadPortalStore } from '../../../core/hermandad/hermandad-portal.store';
import {
  COFRADEO_ACCENT,
  HERMANDAD_COLOR_PRESETS,
  HermandadThemeService,
  normalizeHex,
} from '../../../core/hermandad/hermandad-theme.service';

@Component({
  selector: 'app-hermandad-settings-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './hermandad-settings.component.html',
  styleUrl: './hermandad-settings.component.scss',
})
export class HermandadSettingsPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  readonly store = inject(HermandadPortalStore);
  readonly theme = inject(HermandadThemeService);

  readonly presets = HERMANDAD_COLOR_PRESETS;

  /** Texto del campo hex (puede ir a medias mientras escribe). */
  readonly draftHex = signal(COFRADEO_ACCENT);
  readonly savedFlash = signal(false);

  readonly profile = this.auth.profile;

  readonly boardName = computed(
    () =>
      this.store.primaryBoard()?.hermandadName ??
      this.profile()?.displayName ??
      'Tu hermandad',
  );

  readonly crestUrl = computed(
    () => this.store.primaryBoard()?.iconImageUrl ?? null,
  );

  /** Color válido del borrador (para el swatch). */
  readonly draftSwatch = computed(
    () => normalizeHex(this.draftHex()) ?? this.theme.accent(),
  );

  readonly canSave = computed(() => {
    const normalized = normalizeHex(this.draftHex());
    if (!normalized) return false;
    return (
      this.theme.dirty() ||
      normalized.toLowerCase() !== this.theme.savedAccent().toLowerCase()
    );
  });

  constructor() {
    // Mantener el campo alineado con el acento activo del panel.
    effect(() => {
      this.draftHex.set(this.theme.accent());
    });
  }

  ngOnInit(): void {
    void this.store.ensureLoaded();
  }

  async selectPreset(accent: string): Promise<void> {
    if (!this.theme.applyAccent(accent)) return;
    this.draftHex.set(accent);
    const ok = await this.theme.saveCurrent();
    if (ok) this.flashSaved();
  }

  onColorPicked(value: string): void {
    this.draftHex.set(value);
    this.theme.applyAccent(value);
  }

  onHexText(value: string): void {
    this.draftHex.set(value);
    const normalized = normalizeHex(value);
    if (normalized) this.theme.applyAccent(normalized);
  }

  async saveCustom(): Promise<void> {
    const normalized = normalizeHex(this.draftHex());
    if (!normalized) return;
    this.theme.applyAccent(normalized);
    const ok = await this.theme.saveCurrent();
    if (ok) this.flashSaved();
  }

  async resetTheme(): Promise<void> {
    this.theme.applyDefault();
    this.draftHex.set(COFRADEO_ACCENT);
    const ok = await this.theme.saveCurrent();
    if (ok) this.flashSaved();
  }

  isActivePreset(accent: string): boolean {
    return this.theme.accent().toLowerCase() === accent.toLowerCase();
  }

  private flashSaved(): void {
    this.savedFlash.set(true);
    window.setTimeout(() => this.savedFlash.set(false), 1800);
  }
}
