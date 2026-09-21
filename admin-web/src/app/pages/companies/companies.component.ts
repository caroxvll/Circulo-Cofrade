import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdsService } from '../../core/ads/ads.service';
import {
  CompanyProfile,
  DEFAULT_MAX_ACTIVE_COMPANIES,
  WaitlistEntry,
  placementCommercialName,
} from '../../core/ads/ads.models';

@Component({
  selector: 'app-companies-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './companies.component.html',
  styleUrl: './companies.component.scss',
})
export class CompaniesPageComponent implements OnInit {
  private readonly adsApi = inject(AdsService);

  readonly companies = signal<CompanyProfile[]>([]);
  readonly waitlist = signal<WaitlistEntry[]>([]);
  readonly maxCompanies = signal(DEFAULT_MAX_ACTIVE_COMPANIES);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly savingCupo = signal(false);
  readonly editing = signal<CompanyProfile | null>(null);
  readonly creating = signal(false);

  search = '';
  formName = '';
  formUrl = '';
  formBannerUrl = '';
  formLogoUrl = '';
  cupoDraft = DEFAULT_MAX_ACTIVE_COMPANIES;

  waitName = '';
  waitContact = '';
  waitNotes = '';

  readonly zoneName = placementCommercialName;

  readonly cupo = computed(() => {
    const max = this.maxCompanies();
    const used = this.companies().length;
    return {
      used,
      max,
      full: used >= max,
      free: Math.max(0, max - used),
    };
  });

  readonly nextWait = computed(() => this.waitlist()[0] ?? null);

  readonly dialogOpen = computed(() => this.creating() || !!this.editing());

  ngOnInit(): void {
    void this.reload();
  }

  visible(): CompanyProfile[] {
    const q = this.search.trim().toLowerCase();
    if (!q) return this.companies();
    return this.companies().filter((c) => c.name.toLowerCase().includes(q));
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [ads, waitlist, max] = await Promise.all([
        this.adsApi.fetchAdminAds(),
        this.adsApi.fetchWaitlist().catch((err: unknown) => {
          const message =
            err instanceof Error ? err.message : 'Error lista de espera';
          if (
            message.toLowerCase().includes('sponsor_waitlist') ||
            message.includes('42P01')
          ) {
            throw new Error(
              'Falta crear la tabla de lista de espera. Ejecuta supabase/sponsor_waitlist.sql',
            );
          }
          throw err;
        }),
        this.adsApi.fetchMaxActiveCompanies(),
      ]);
      this.companies.set(this.adsApi.listCompanies(ads));
      this.waitlist.set(waitlist);
      this.maxCompanies.set(max);
      this.cupoDraft = max;
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudieron cargar las empresas',
      );
    } finally {
      this.loading.set(false);
    }
  }

  async saveCupo(): Promise<void> {
    const next = Math.round(Number(this.cupoDraft));
    if (!Number.isFinite(next) || next < 1 || next > 100) {
      this.error.set('El cupo debe estar entre 1 y 100.');
      return;
    }
    if (next < this.companies().length) {
      this.error.set(
        `Hay ${this.companies().length} empresas activas. Baja el cupo solo si quitas marcas antes, o pon al menos ${this.companies().length}.`,
      );
      return;
    }
    this.savingCupo.set(true);
    this.error.set(null);
    try {
      const saved = await this.adsApi.updateMaxActiveCompanies(next);
      this.maxCompanies.set(saved);
      this.cupoDraft = saved;
    } catch (err) {
      this.error.set(
        err instanceof Error ? err.message : 'No se pudo guardar el cupo',
      );
    } finally {
      this.savingCupo.set(false);
    }
  }

  openCreate(): void {
    if (this.cupo().full) {
      this.error.set(
        `Cupo lleno (${this.cupo().used}/${this.cupo().max}). Libera un hueco o añádela a la lista de espera.`,
      );
      return;
    }
    this.editing.set(null);
    this.creating.set(true);
    this.formName = '';
    this.formUrl = '';
    this.formBannerUrl = '';
    this.formLogoUrl = '';
    this.error.set(null);
  }

  openEdit(company: CompanyProfile): void {
    this.creating.set(false);
    this.editing.set(company);
    this.formName = company.name;
    this.formUrl = company.targetUrl;
    this.formBannerUrl = company.imageUrl ?? '';
    this.formLogoUrl = company.sponsorLogoUrl ?? '';
  }

  closeDialog(): void {
    this.creating.set(false);
    this.editing.set(null);
  }

  async onUpload(kind: 'banner' | 'logo', event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      const url = await this.adsApi.uploadAdAsset(
        file,
        kind === 'banner' ? 'images' : 'logos',
      );
      if (kind === 'banner') this.formBannerUrl = url;
      else this.formLogoUrl = url;
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo subir');
    } finally {
      this.saving.set(false);
      input.value = '';
    }
  }

  async save(): Promise<void> {
    if (this.formName.trim().length < 2) {
      this.error.set('El nombre debe tener al menos 2 caracteres.');
      return;
    }

    this.saving.set(true);
    this.error.set(null);
    try {
      if (this.creating()) {
        const createdName = this.formName.trim();
        await this.adsApi.createCompany({
          name: createdName,
          targetUrl: this.formUrl,
          imageUrl: this.formBannerUrl.trim() || null,
          sponsorLogoUrl: this.formLogoUrl.trim() || null,
        });
        this.closeDialog();
        await this.reload();
        alert(
          `Empresa «${createdName}» creada. Ya puedes colocarla en zonas desde Patrocinios.`,
        );
        return;
      }

      const current = this.editing();
      if (!current) return;
      const n = await this.adsApi.updateCompany({
        currentName: current.name,
        name: this.formName,
        targetUrl: this.formUrl,
        imageUrl: this.formBannerUrl.trim() || null,
        sponsorLogoUrl: this.formLogoUrl.trim() || null,
      });
      this.closeDialog();
      await this.reload();
      alert(`Actualizado en ${n} pieza${n === 1 ? '' : 's'}.`);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar');
    } finally {
      this.saving.set(false);
    }
  }

  async removeCompany(company: CompanyProfile): Promise<void> {
    const next = this.nextWait();
    const nextHint = next
      ? `\n\nSiguiente en lista de espera: ${next.companyName}.`
      : '';
    const ok = confirm(
      `¿Quitar «${company.name}»?\n\nSe eliminarán ${company.adIds.length} pieza(s) de patrocinios y sus cobros en Finanzas.${nextHint}`,
    );
    if (!ok) return;

    this.saving.set(true);
    this.error.set(null);
    try {
      const result = await this.adsApi.deleteCompany(company.name);
      await this.reload();
      const nextAfter = this.nextWait();
      alert(
        `Eliminado: ${result.adsDeleted} pieza(s) y ${result.paymentsDeleted} cobro(s).` +
          (nextAfter
            ? `\nHueco libre. Siguiente en espera: ${nextAfter.companyName}.`
            : '\nHueco libre en el cupo.'),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar');
    } finally {
      this.saving.set(false);
    }
  }

  async addToWaitlist(): Promise<void> {
    if (this.waitName.trim().length < 2) {
      this.error.set('Indica el nombre de la empresa en espera.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.adsApi.addWaitlistEntry({
        companyName: this.waitName,
        contact: this.waitContact,
        notes: this.waitNotes,
      });
      this.waitName = '';
      this.waitContact = '';
      this.waitNotes = '';
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo añadir');
    } finally {
      this.saving.set(false);
    }
  }

  async removeWait(entry: WaitlistEntry): Promise<void> {
    if (!confirm(`¿Quitar «${entry.companyName}» de la lista de espera?`)) return;
    try {
      await this.adsApi.removeWaitlistEntry(entry.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo quitar');
    }
  }
}
