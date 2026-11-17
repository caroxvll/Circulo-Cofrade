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
  readonly brandingBusy = signal(false);
  readonly brandingError = signal<string | null>(null);
  readonly brandingOk = signal<string | null>(null);

  readonly profile = this.auth.profile;

  readonly boardName = computed(
    () =>
      this.store.primaryBoard()?.hermandadName ??
      this.profile()?.displayName ??
      'Tu hermandad',
  );

  readonly topicId = computed(() => this.store.primaryBoard()?.topicId ?? null);

  readonly crestUrl = computed(
    () => this.store.primaryBoard()?.iconImageUrl ?? null,
  );

  readonly coverUrl = computed(
    () => this.store.primaryBoard()?.coverImageUrl ?? null,
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

  async onAssetPicked(kind: 'cover' | 'escudo', event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;

    const topicId = this.topicId();
    if (!topicId) {
      this.brandingError.set('No hay tablón asignado a tu cuenta.');
      return;
    }

    this.brandingBusy.set(true);
    this.brandingError.set(null);
    this.brandingOk.set(null);
    try {
      await this.store.updateBoardBranding(topicId, {
        coverFile: kind === 'cover' ? file : null,
        iconFile: kind === 'escudo' ? file : null,
      });
      this.brandingOk.set(
        kind === 'cover' ? 'Portada actualizada' : 'Escudo actualizado',
      );
      this.flashSaved();
      window.setTimeout(() => this.brandingOk.set(null), 2200);
    } catch (err) {
      this.brandingError.set(
        err instanceof Error ? err.message : 'No se pudo subir la imagen',
      );
    } finally {
      this.brandingBusy.set(false);
    }
  }

  async clearAsset(kind: 'cover' | 'escudo'): Promise<void> {
    const topicId = this.topicId();
    if (!topicId) return;

    this.brandingBusy.set(true);
    this.brandingError.set(null);
    this.brandingOk.set(null);
    try {
      await this.store.updateBoardBranding(topicId, {
        clearCover: kind === 'cover',
        clearIcon: kind === 'escudo',
      });
      this.brandingOk.set(
        kind === 'cover' ? 'Portada eliminada' : 'Escudo eliminado',
      );
      this.flashSaved();
      window.setTimeout(() => this.brandingOk.set(null), 2200);
    } catch (err) {
      this.brandingError.set(
        err instanceof Error ? err.message : 'No se pudo quitar la imagen',
      );
    } finally {
      this.brandingBusy.set(false);
    }
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
