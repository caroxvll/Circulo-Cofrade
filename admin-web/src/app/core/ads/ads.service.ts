import { Injectable, inject } from '@angular/core';
import { getSupabase } from '../supabase.client';
import { FinanceService } from '../finance/finance.service';
import {
  AdPlacement,
  AdStatisticsRow,
  COMPANY_CATALOG_PLACEMENT,
  CompanyProfile,
  DEFAULT_MAX_ACTIVE_COMPANIES,
  PackSponsorOption,
  SaveAdInput,
  SponsoredAd,
  WaitlistEntry,
  adDisplayName,
  companyKeyFromName,
  isCompanyCatalogPlacement,
  normalizeAdTargetUrl,
} from './ads.models';

@Injectable({ providedIn: 'root' })
export class AdsService {
  private readonly finance = inject(FinanceService);
  private cachedMaxCompanies: number | null = null;

  async fetchMaxActiveCompanies(): Promise<number> {
    try {
      const { data, error } = await getSupabase()
        .from('sponsor_settings')
        .select('max_active_companies')
        .eq('id', 1)
        .maybeSingle();
      if (error) throw error;
      const value = Number(data?.['max_active_companies'] ?? DEFAULT_MAX_ACTIVE_COMPANIES);
      const max = Number.isFinite(value)
        ? Math.min(100, Math.max(1, Math.round(value)))
        : DEFAULT_MAX_ACTIVE_COMPANIES;
      this.cachedMaxCompanies = max;
      return max;
    } catch {
      this.cachedMaxCompanies = DEFAULT_MAX_ACTIVE_COMPANIES;
      return DEFAULT_MAX_ACTIVE_COMPANIES;
    }
  }

  async updateMaxActiveCompanies(max: number): Promise<number> {
    const next = Math.min(100, Math.max(1, Math.round(max)));
    if (!Number.isFinite(next)) {
      throw new Error('Indica un cupo entre 1 y 100.');
    }
    const { data, error } = await getSupabase()
      .from('sponsor_settings')
      .upsert(
        {
          id: 1,
          max_active_companies: next,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'id' },
      )
      .select('max_active_companies')
      .single();
    if (error) {
      if (
        error.message.toLowerCase().includes('sponsor_settings') ||
        error.code === '42P01'
      ) {
        throw new Error(
          'Falta la tabla de cupo. Ejecuta supabase/sponsor_settings.sql',
        );
      }
      throw error;
    }
    const saved = Number(data?.['max_active_companies'] ?? next);
    this.cachedMaxCompanies = saved;
    return saved;
  }
  async fetchAdminAds(): Promise<SponsoredAd[]> {
    const { data, error } = await getSupabase()
      .from('ads')
      .select('*')
      .order('placement', { ascending: true })
      .order('priority', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapAd(row));
  }

  async saveAd(input: SaveAdInput): Promise<void> {
    if (!input.skipCupoCheck) {
      await this.assertCompanySlot(input.sponsorName.trim() || input.title.trim(), {
        editingAdId: input.id,
      });
    }

    const payload = {
      title: input.title.trim(),
      description: (input.description ?? '').trim(),
      sponsor_name: input.sponsorName.trim(),
      button_text: (input.buttonText ?? 'Ver más').trim() || 'Ver más',
      target_url: normalizeAdTargetUrl(input.targetUrl),
      placement: input.placement,
      image_url: this.emptyToNull(input.imageUrl),
      sponsor_logo_url: this.emptyToNull(input.sponsorLogoUrl),
      calendar_event_id: this.emptyToNull(input.calendarEventId),
      forum_id: this.emptyToNull(input.forumId),
      topic_id: this.emptyToNull(input.topicId),
      priority: input.priority,
      max_impressions: input.maxImpressions ?? 1_000_000,
      active: input.active,
    };

    if (input.id) {
      const { error } = await getSupabase()
        .from('ads')
        .update(payload)
        .eq('id', input.id);
      if (error) throw error;
      return;
    }

    const { error } = await getSupabase().from('ads').insert(payload);
    if (error) throw error;

    await this.removeWaitlistByName(input.sponsorName.trim() || input.title.trim());
  }

  /**
   * Borra la marca de todas partes: piezas `ads` + cobros `sponsor_payments`.
   * Libera un hueco del cupo.
   */
  async deleteCompany(companyName: string): Promise<{ adsDeleted: number; paymentsDeleted: number }> {
    const key = companyKeyFromName(companyName);
    if (!key) throw new Error('Nombre de empresa vacío.');

    const ads = await this.fetchAdminAds();
    const targets = ads.filter((ad) => companyKeyFromName(adDisplayName(ad)) === key);
    for (const ad of targets) {
      await this.deleteAd(ad.id);
    }

    const paymentsDeleted = await this.finance.deletePaymentsBySponsor(companyName);
    return { adsDeleted: targets.length, paymentsDeleted };
  }

  async equalizePlacement(placement: AdPlacement, priority = 10): Promise<number> {
    const ads = await this.fetchAdminAds();
    const targets = ads.filter((ad) => ad.placement === placement && ad.active);
    let updated = 0;
    for (const ad of targets) {
      if (ad.priority === priority) continue;
      await this.saveAd({
        id: ad.id,
        title: ad.title,
        description: ad.description,
        sponsorName: ad.sponsorName,
        buttonText: ad.buttonText,
        targetUrl: ad.targetUrl,
        placement: ad.placement,
        imageUrl: ad.imageUrl,
        sponsorLogoUrl: ad.sponsorLogoUrl,
        calendarEventId: ad.calendarEventId,
        forumId: ad.forumId,
        topicId: ad.topicId,
        priority,
        maxImpressions: ad.maxImpressions,
        active: ad.active,
        skipCupoCheck: true,
      });
      updated += 1;
    }
    return updated;
  }

  async fetchWaitlist(): Promise<WaitlistEntry[]> {
    const { data, error } = await getSupabase()
      .from('sponsor_waitlist')
      .select('*')
      .order('created_at', { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row) => this.mapWaitlist(row));
  }

  async addWaitlistEntry(input: {
    companyName: string;
    contact?: string;
    notes?: string;
  }): Promise<void> {
    const name = input.companyName.trim();
    if (name.length < 2) throw new Error('Indica el nombre de la empresa.');

    const ads = await this.fetchAdminAds();
    const companies = this.listCompanies(ads);
    if (companies.some((c) => c.key === companyKeyFromName(name))) {
      throw new Error('Esa empresa ya está activa en patrocinios.');
    }

    const { error } = await getSupabase().from('sponsor_waitlist').insert({
      company_name: name,
      contact: (input.contact ?? '').trim(),
      notes: (input.notes ?? '').trim(),
    });
    if (error) {
      if (error.code === '23505') {
        throw new Error('Esa empresa ya está en la lista de espera.');
      }
      throw error;
    }
  }

  async removeWaitlistEntry(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('sponsor_waitlist')
      .delete()
      .eq('id', id);
    if (error) throw error;
  }

  private async removeWaitlistByName(companyName: string): Promise<void> {
    const key = companyKeyFromName(companyName);
    if (!key) return;
    try {
      const list = await this.fetchWaitlist();
      const hit = list.find((entry) => companyKeyFromName(entry.companyName) === key);
      if (hit) await this.removeWaitlistEntry(hit.id);
    } catch {
      // Tabla aún no creada o sin permisos: no bloquea el alta del anuncio.
    }
  }

  /** True si al añadir esta marca se supera el cupo configurado. */
  isCupoFull(
    ads: SponsoredAd[],
    newCompanyName?: string,
    maxCompanies = this.cachedMaxCompanies ?? DEFAULT_MAX_ACTIVE_COMPANIES,
  ): boolean {
    const companies = this.listCompanies(ads);
    if (companies.length < maxCompanies) return false;
    if (!newCompanyName?.trim()) return true;
    const key = companyKeyFromName(newCompanyName);
    return !companies.some((c) => c.key === key);
  }

  private async assertCompanySlot(
    companyName: string,
    opts: { editingAdId?: string },
  ): Promise<void> {
    const key = companyKeyFromName(companyName);
    if (!key) return;

    const max = await this.fetchMaxActiveCompanies();
    const ads = await this.fetchAdminAds();
    const companies = this.listCompanies(
      opts.editingAdId ? ads.filter((ad) => ad.id !== opts.editingAdId) : ads,
    );
    if (companies.some((c) => c.key === key)) return;
    if (companies.length < max) return;

    throw new Error(
      `Cupo lleno (${companies.length}/${max} empresas). Añádela a la lista de espera en Empresas o libera un hueco.`,
    );
  }

  private mapWaitlist(row: Record<string, unknown>): WaitlistEntry {
    return {
      id: String(row['id'] ?? ''),
      companyName: String(row['company_name'] ?? ''),
      contact: String(row['contact'] ?? ''),
      notes: String(row['notes'] ?? ''),
      createdAt: String(row['created_at'] ?? ''),
    };
  }

  async deleteAd(adId: string): Promise<void> {
    const { error } = await getSupabase().from('ads').delete().eq('id', adId);
    if (error) throw error;
  }

  async setAdActive(adId: string, active: boolean): Promise<void> {
    const { error } = await getSupabase()
      .from('ads')
      .update({ active })
      .eq('id', adId);
    if (error) throw error;
  }

  async fetchAdStatistics(from?: Date | null, to?: Date | null): Promise<AdStatisticsRow[]> {
    const { data, error } = await getSupabase().rpc('get_ad_statistics', {
      p_from: from ? from.toISOString() : null,
      p_to: to ? to.toISOString() : null,
    });
    if (error) throw error;
    return ((data as Record<string, unknown>[]) ?? []).map((row) => ({
      id: String(row['id'] ?? ''),
      title: String(row['title'] ?? ''),
      sponsorName: String(row['sponsor_name'] ?? ''),
      placement: String(row['placement'] ?? '') as AdPlacement,
      trackedImpressions: Number(row['tracked_impressions'] ?? 0),
      clicks: Number(row['clicks'] ?? 0),
      ctr: Number(row['ctr'] ?? 0),
      currentImpressions: Number(row['current_impressions'] ?? 0),
    }));
  }

  packSponsorsFromAds(ads: SponsoredAd[]): PackSponsorOption[] {
    const byKey = new Map<string, PackSponsorOption>();
    for (const ad of ads) {
      const name = adDisplayName(ad);
      const key = name.toLowerCase();
      const existing = byKey.get(key);
      if (!existing) {
        byKey.set(key, {
          name,
          targetUrl: ad.targetUrl,
          imageUrl: ad.imageUrl,
          sponsorLogoUrl: ad.sponsorLogoUrl,
        });
        continue;
      }
      if (!existing.imageUrl && ad.imageUrl) existing.imageUrl = ad.imageUrl;
      if (!existing.sponsorLogoUrl && ad.sponsorLogoUrl) {
        existing.sponsorLogoUrl = ad.sponsorLogoUrl;
      }
      if (!existing.targetUrl && ad.targetUrl) existing.targetUrl = ad.targetUrl;
    }
    return [...byKey.values()]
      .filter((s) => !!s.imageUrl)
      .sort((a, b) => a.name.localeCompare(b.name, 'es'));
  }

  /** Catálogo de marcas a partir de las piezas `ads` (sin tabla propia). */
  listCompanies(ads: SponsoredAd[]): CompanyProfile[] {
    const byKey = new Map<string, CompanyProfile>();
    for (const ad of ads) {
      const name = adDisplayName(ad);
      const key = name.toLowerCase();
      const existing = byKey.get(key);
      const zonePlacement = isCompanyCatalogPlacement(ad.placement)
        ? null
        : ad.placement;
      if (!existing) {
        byKey.set(key, {
          key,
          name,
          targetUrl: ad.targetUrl,
          imageUrl: ad.imageUrl,
          sponsorLogoUrl: ad.sponsorLogoUrl,
          placements: zonePlacement ? [zonePlacement] : [],
          adIds: [ad.id],
          activeCount: ad.active && zonePlacement ? 1 : 0,
        });
        continue;
      }
      if (!existing.imageUrl && ad.imageUrl) existing.imageUrl = ad.imageUrl;
      if (!existing.sponsorLogoUrl && ad.sponsorLogoUrl) {
        existing.sponsorLogoUrl = ad.sponsorLogoUrl;
      }
      if (!existing.targetUrl && ad.targetUrl) existing.targetUrl = ad.targetUrl;
      if (zonePlacement && !existing.placements.includes(zonePlacement)) {
        existing.placements.push(zonePlacement);
      }
      existing.adIds.push(ad.id);
      if (ad.active && zonePlacement) existing.activeCount += 1;
    }
    return [...byKey.values()].sort((a, b) =>
      a.name.localeCompare(b.name, 'es'),
    );
  }

  /**
   * Alta de marca en el catálogo (ficha inactiva en placement reservado).
   * Luego se coloca en zonas desde Patrocinios.
   */
  async createCompany(input: {
    name: string;
    targetUrl: string;
    imageUrl: string | null;
    sponsorLogoUrl: string | null;
  }): Promise<void> {
    const name = input.name.trim();
    if (name.length < 2) {
      throw new Error('El nombre debe tener al menos 2 caracteres.');
    }

    const ads = await this.fetchAdminAds();
    if (this.listCompanies(ads).some((c) => c.key === companyKeyFromName(name))) {
      throw new Error('Esa empresa ya está creada.');
    }

    await this.saveAd({
      title: name,
      description: '',
      sponsorName: name,
      buttonText: 'Ver más',
      targetUrl: input.targetUrl,
      placement: COMPANY_CATALOG_PLACEMENT,
      imageUrl: input.imageUrl,
      sponsorLogoUrl: input.sponsorLogoUrl,
      forumId: null,
      topicId: null,
      calendarEventId: null,
      priority: 1,
      maxImpressions: 1,
      active: false,
    });
  }

  /**
   * Actualiza creatividades de una marca en todas sus piezas.
   * Banner = image_url · Logo eventos = sponsor_logo_url.
   */
  async updateCompany(input: {
    currentName: string;
    name: string;
    targetUrl: string;
    imageUrl: string | null;
    sponsorLogoUrl: string | null;
  }): Promise<number> {
    const ads = await this.fetchAdminAds();
    const currentKey = input.currentName.trim().toLowerCase();
    const targets = ads.filter(
      (ad) => adDisplayName(ad).toLowerCase() === currentKey,
    );
    if (!targets.length) {
      throw new Error('No se encontraron piezas de esa empresa.');
    }

    const name = input.name.trim();
    const targetUrl = normalizeAdTargetUrl(input.targetUrl);
    let updated = 0;
    for (const ad of targets) {
      await this.saveAd({
        id: ad.id,
        title: ad.title.trim().toLowerCase() === currentKey ? name : ad.title,
        description: ad.description,
        sponsorName: name,
        buttonText: ad.buttonText,
        targetUrl: targetUrl || ad.targetUrl,
        placement: ad.placement,
        imageUrl: input.imageUrl,
        sponsorLogoUrl: input.sponsorLogoUrl,
        calendarEventId: ad.calendarEventId,
        forumId: ad.forumId,
        topicId: ad.topicId,
        priority: ad.priority,
        maxImpressions: ad.maxImpressions,
        active: ad.active,
        skipCupoCheck: true,
      });
      updated += 1;
    }

    if (companyKeyFromName(name) !== currentKey) {
      await this.finance.renameSponsorPayments(input.currentName, name);
    }

    return updated;
  }

  async savePack(input: {
    sponsor: PackSponsorOption;
    zones: AdPlacement[];
  }): Promise<number> {
    await this.assertCompanySlot(input.sponsor.name, {});
    const imageUrl =
      (input.sponsor.imageUrl ?? '').trim() ||
      (input.sponsor.sponsorLogoUrl ?? '').trim() ||
      null;
    if (!imageUrl) {
      throw new Error('Esa marca no tiene imagen. Sube creativo en una pieza primero.');
    }
    let created = 0;
    for (const placement of input.zones) {
      await this.saveAd({
        title: input.sponsor.name,
        description: '',
        sponsorName: input.sponsor.name,
        buttonText: 'Ver más',
        targetUrl: input.sponsor.targetUrl,
        placement,
        imageUrl,
        sponsorLogoUrl: input.sponsor.sponsorLogoUrl,
        forumId: null,
        topicId: null,
        calendarEventId: null,
        priority: 10,
        maxImpressions: 1_000_000,
        active: true,
      });
      created += 1;
    }
    return created;
  }

  async uploadAdAsset(file: File, folder: 'images' | 'logos'): Promise<string> {
    if (file.size > 4 * 1024 * 1024) {
      throw new Error('La imagen no puede superar 4 MB.');
    }
    const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
    const path = `${folder}/${Date.now()}.${ext}`;
    const { error } = await getSupabase().storage.from('ad-assets').upload(path, file, {
      upsert: true,
      contentType: file.type || 'image/jpeg',
    });
    if (error) throw error;
    return getSupabase().storage.from('ad-assets').getPublicUrl(path).data.publicUrl;
  }

  private emptyToNull(value?: string | null): string | null {
    const trimmed = value?.trim();
    if (!trimmed) return null;
    return trimmed;
  }

  private mapAd(row: Record<string, unknown>): SponsoredAd {
    return {
      id: String(row['id'] ?? ''),
      title: String(row['title'] ?? ''),
      description: String(row['description'] ?? ''),
      sponsorName: String(row['sponsor_name'] ?? ''),
      buttonText: String(row['button_text'] ?? 'Ver más'),
      targetUrl: String(row['target_url'] ?? ''),
      placement: String(row['placement'] ?? 'forums_top') as AdPlacement,
      imageUrl: (row['image_url'] as string | null) ?? null,
      sponsorLogoUrl: (row['sponsor_logo_url'] as string | null) ?? null,
      calendarEventId: (row['calendar_event_id'] as string | null) ?? null,
      forumId: (row['forum_id'] as string | null) ?? null,
      topicId: (row['topic_id'] as string | null) ?? null,
      priority: Number(row['priority'] ?? 1),
      maxImpressions: Number(row['max_impressions'] ?? 1_000_000),
      currentImpressions: Number(row['current_impressions'] ?? 0),
      active: Boolean(row['active']),
      createdAt: String(row['created_at'] ?? ''),
    };
  }
}
