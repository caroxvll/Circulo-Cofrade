import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  FORUM_ICON_KEYS,
  ForumPillar,
  ForumsService,
  PINNED_PARENT_FORUM_IDS,
  PinnedSystemTopic,
  SEASON_KEYS,
} from '../../core/forums/forums.service';

type DialogKind = 'pillar' | 'cover' | 'topic-edit' | 'topic-new' | null;

@Component({
  selector: 'app-forums-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './forums.component.html',
  styleUrl: './forums.component.scss',
})
export class ForumsPageComponent implements OnInit {
  private readonly forumsApi = inject(ForumsService);

  readonly pillars = signal<ForumPillar[]>([]);
  readonly pinned = signal<PinnedSystemTopic[]>([]);
  readonly heroUrl = signal<string | null>(null);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly busyId = signal<string | null>(null);
  readonly dialog = signal<DialogKind>(null);
  readonly editingPillar = signal<ForumPillar | null>(null);
  readonly editingTopic = signal<PinnedSystemTopic | null>(null);

  search = '';
  formName = '';
  formDescription = '';
  formTagline = '';
  formAbout = '';
  formRules = '';
  formCoverUrl = '';

  topicForumId: string = PINNED_PARENT_FORUM_IDS[0];
  topicTitle = '';
  topicExcerpt = '';
  topicBody = '';
  topicSeason = '';
  topicIcon = 'church';
  topicCoverUrl = '';
  topicListed = true;
  topicShowHubTitle = true;

  readonly iconKeys = FORUM_ICON_KEYS;
  readonly seasonKeys = SEASON_KEYS;
  readonly parentForumIds = PINNED_PARENT_FORUM_IDS;
  readonly parentLabel = (id: string) => this.forumsApi.parentForumLabel(id);
  readonly seasonLabel = (key: string | null) => this.forumsApi.seasonLabel(key);

  readonly pinnedGroups = computed(() =>
    PINNED_PARENT_FORUM_IDS.map((forumId) => ({
      forumId,
      label: this.forumsApi.parentForumLabel(forumId),
      topics: this.pinned()
        .filter((t) => t.forumId === forumId)
        .sort((a, b) => a.pinSortOrder - b.pinSortOrder),
    })),
  );

  ngOnInit(): void {
    void this.reload();
  }

  visible(): ForumPillar[] {
    const q = this.search.trim().toLowerCase();
    if (!q) return this.pillars();
    return this.pillars().filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        p.id.toLowerCase().includes(q) ||
        p.description.toLowerCase().includes(q),
    );
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [pillars, pinned, hero] = await Promise.all([
        this.forumsApi.fetchPillars(),
        this.forumsApi.fetchPinnedSystemTopics(),
        this.forumsApi.fetchForumsListHeroUrl().catch(() => null),
      ]);
      this.pillars.set(pillars);
      this.pinned.set(pinned);
      this.heroUrl.set(hero);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudieron cargar los foros');
    } finally {
      this.loading.set(false);
    }
  }

  closeDialog(): void {
    this.dialog.set(null);
    this.editingPillar.set(null);
    this.editingTopic.set(null);
  }

  openEdit(pillar: ForumPillar): void {
    this.editingPillar.set(pillar);
    this.formName = pillar.name;
    this.formDescription = pillar.description;
    this.formTagline = pillar.aboutTagline ?? '';
    this.formAbout = pillar.aboutBody ?? '';
    this.formRules = pillar.forumRules ?? '';
    this.dialog.set('pillar');
  }

  openCover(pillar: ForumPillar): void {
    this.editingPillar.set(pillar);
    this.formCoverUrl = pillar.coverImageUrl ?? '';
    this.dialog.set('cover');
  }

  openNewTopic(forumId?: string): void {
    this.editingTopic.set(null);
    this.topicForumId = forumId ?? PINNED_PARENT_FORUM_IDS[0];
    this.topicTitle = '';
    this.topicExcerpt = '';
    this.topicBody = '';
    this.topicSeason = this.topicForumId === 'foro-cofradiero' ? 'cuaresma' : '';
    this.topicIcon = 'church';
    this.dialog.set('topic-new');
  }

  openEditTopic(topic: PinnedSystemTopic): void {
    this.editingTopic.set(topic);
    this.topicExcerpt = topic.excerpt;
    this.topicBody = topic.body;
    this.topicIcon = topic.iconKey || 'church';
    this.topicCoverUrl = topic.coverImageUrl ?? '';
    this.topicListed = topic.isListed;
    this.topicShowHubTitle = topic.showHubTitle;
    this.dialog.set('topic-edit');
  }

  async toggleEnabled(pillar: ForumPillar): Promise<void> {
    this.busyId.set(pillar.id);
    this.error.set(null);
    try {
      const next = !pillar.isEnabled;
      await this.forumsApi.updatePillar({ id: pillar.id, isEnabled: next });
      this.pillars.update((list) =>
        list.map((p) => (p.id === pillar.id ? { ...p, isEnabled: next } : p)),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cambiar la visibilidad');
    } finally {
      this.busyId.set(null);
    }
  }

  async toggleActive(pillar: ForumPillar): Promise<void> {
    this.busyId.set(pillar.id);
    this.error.set(null);
    try {
      const next = !pillar.isActive;
      await this.forumsApi.updatePillar({ id: pillar.id, isActive: next });
      this.pillars.update((list) =>
        list.map((p) => (p.id === pillar.id ? { ...p, isActive: next } : p)),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cambiar el badge');
    } finally {
      this.busyId.set(null);
    }
  }

  canDeletePillar(pillar: ForumPillar): boolean {
    return this.forumsApi.canDeletePillar(pillar.id);
  }

  async removePillar(pillar: ForumPillar): Promise<void> {
    if (!this.canDeletePillar(pillar)) {
      this.error.set('Este foro es del núcleo de la app y no se puede eliminar.');
      return;
    }
    const topicsNote =
      pillar.topicCount > 0
        ? `\n\nSe borrarán también sus ${pillar.topicCount} tema(s) y mensajes.`
        : '';
    if (
      !confirm(
        `¿Eliminar el foro «${pillar.name}» (${pillar.id})?${topicsNote}\n\nEsta acción no se puede deshacer.`,
      )
    ) {
      return;
    }
    if (
      pillar.topicCount > 0 &&
      !confirm(`Confirma otra vez: borrar «${pillar.name}» y todo su contenido.`)
    ) {
      return;
    }
    this.busyId.set(pillar.id);
    this.error.set(null);
    try {
      await this.forumsApi.deletePillar(pillar.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar el foro');
    } finally {
      this.busyId.set(null);
    }
  }

  async saveEdit(): Promise<void> {
    const current = this.editingPillar();
    if (!current) return;
    if (this.formName.trim().length < 2) {
      this.error.set('El nombre debe tener al menos 2 caracteres.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.forumsApi.updatePillar({
        id: current.id,
        name: this.formName,
        description: this.formDescription,
        aboutTagline: this.formTagline,
        aboutBody: this.formAbout,
        forumRules: this.formRules,
      });
      this.closeDialog();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar');
    } finally {
      this.saving.set(false);
    }
  }

  async saveCover(): Promise<void> {
    const current = this.editingPillar();
    if (!current) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.forumsApi.updatePillar({
        id: current.id,
        coverImageUrl: this.formCoverUrl.trim() || null,
      });
      this.closeDialog();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar la portada');
    } finally {
      this.saving.set(false);
    }
  }

  async onHeroUpload(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      const url = await this.forumsApi.uploadForumsListHero(file);
      await this.forumsApi.setForumsListHeroUrl(url);
      this.heroUrl.set(url);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo subir el hero');
    } finally {
      this.saving.set(false);
      input.value = '';
    }
  }

  async clearHero(): Promise<void> {
    if (!confirm('¿Quitar la imagen hero de la lista FOROS?')) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.forumsApi.setForumsListHeroUrl('');
      this.heroUrl.set(null);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo restaurar');
    } finally {
      this.saving.set(false);
    }
  }

  async onPillarCoverUpload(event: Event): Promise<void> {
    const current = this.editingPillar();
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!current || !file) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      this.formCoverUrl = await this.forumsApi.uploadPillarCover(current.id, file);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo subir');
    } finally {
      this.saving.set(false);
      input.value = '';
    }
  }

  async onTopicCoverUpload(event: Event): Promise<void> {
    const current = this.editingTopic();
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!current || !file) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      this.topicCoverUrl = await this.forumsApi.uploadTopicCover(current.id, file);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo subir');
    } finally {
      this.saving.set(false);
      input.value = '';
    }
  }

  async createTopic(): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.forumsApi.createPinnedSystemTopic({
        forumId: this.topicForumId,
        title: this.topicTitle,
        excerpt: this.topicExcerpt,
        body: this.topicBody,
        seasonKey: this.topicSeason || null,
        iconKey: this.topicIcon,
      });
      this.closeDialog();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo crear el tema');
    } finally {
      this.saving.set(false);
    }
  }

  async saveTopic(): Promise<void> {
    const current = this.editingTopic();
    if (!current) return;
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.forumsApi.updatePinnedTopicSettings({
        id: current.id,
        excerpt: this.topicExcerpt,
        body: this.topicBody,
        iconKey: this.topicIcon,
        coverImageUrl: this.topicCoverUrl.trim() || null,
        isListed: this.topicListed,
        showHubTitle: this.topicShowHubTitle,
      });
      this.closeDialog();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar el tema');
    } finally {
      this.saving.set(false);
    }
  }

  async toggleTopicListed(topic: PinnedSystemTopic): Promise<void> {
    this.busyId.set(topic.id);
    try {
      const next = !topic.isListed;
      await this.forumsApi.updatePinnedTopicSettings({ id: topic.id, isListed: next });
      this.pinned.update((list) =>
        list.map((t) => (t.id === topic.id ? { ...t, isListed: next } : t)),
      );
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cambiar la visibilidad');
    } finally {
      this.busyId.set(null);
    }
  }

  async moveTopic(topic: PinnedSystemTopic, dir: -1 | 1): Promise<void> {
    const group = this.pinned()
      .filter((t) => t.forumId === topic.forumId)
      .sort((a, b) => a.pinSortOrder - b.pinSortOrder);
    const idx = group.findIndex((t) => t.id === topic.id);
    const swap = group[idx + dir];
    if (!swap) return;
    this.busyId.set(topic.id);
    try {
      await this.forumsApi.swapPinnedOrder(topic, swap);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo reordenar');
    } finally {
      this.busyId.set(null);
    }
  }

  async removeTopic(topic: PinnedSystemTopic): Promise<void> {
    if (!confirm(`¿Eliminar el tema destacado «${topic.title}»?`)) return;
    this.busyId.set(topic.id);
    try {
      await this.forumsApi.deletePinnedSystemTopic(topic.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo eliminar');
    } finally {
      this.busyId.set(null);
    }
  }
}
