import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/auth/auth.service';
import {
  QuizLivePayload,
  QuizOption,
  QuizQuestion,
  QuizService,
} from '../../core/quiz/quiz.service';

type QuizFilter = 'ready' | 'pending' | 'all';

@Component({
  selector: 'app-quiz-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './quiz.component.html',
  styleUrl: './quiz.component.scss',
})
export class QuizPageComponent implements OnInit {
  private readonly quizApi = inject(QuizService);
  private readonly auth = inject(AuthService);

  readonly questions = signal<QuizQuestion[]>([]);
  readonly launchedIds = signal<Set<string>>(new Set());
  readonly live = signal<QuizLivePayload | null>(null);
  readonly liveVisible = signal(true);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);
  readonly busyId = signal<string | null>(null);
  readonly showForm = signal(false);
  readonly filter = signal<QuizFilter>('ready');

  seasonStartsOn = '';
  seasonMessage = '';

  formPrompt = '';
  formA = '';
  formB = '';
  formC = '';
  formD = '';
  formCorrect: QuizOption = 'a';
  formExplanation = '';
  formImageUrl = '';

  readonly isAdmin = computed(() => this.auth.isAdmin());
  readonly statusLabel = (s: QuizQuestion['status']) => this.quizApi.statusLabel(s);

  readonly visibleQuestions = computed(() => {
    const filter = this.filter();
    const launched = this.launchedIds();
    return this.questions().filter((q) => {
      if (filter === 'pending') return q.status === 'pending_review';
      if (filter === 'ready') {
        return q.status === 'approved' && !launched.has(q.id);
      }
      return true;
    });
  });

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const [questions, launched, live, visible, season] = await Promise.all([
        this.quizApi.fetchQuestions(),
        this.quizApi.fetchLaunchedQuestionIds(),
        this.quizApi.fetchLivePayload().catch(() => null),
        this.quizApi.fetchLiveVisible().catch(() => true),
        this.quizApi.fetchSeasonInfo().catch(() => ({ startsOn: null, message: null })),
      ]);
      this.questions.set(questions);
      this.launchedIds.set(launched);
      this.live.set(live);
      this.liveVisible.set(visible);
      this.seasonStartsOn = season.startsOn ?? '';
      this.seasonMessage = season.message ?? '';
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿SQL de quiz ejecutado?`
          : 'No se pudo cargar el quiz',
      );
    } finally {
      this.loading.set(false);
    }
  }

  openCreate(): void {
    this.formPrompt = '';
    this.formA = '';
    this.formB = '';
    this.formC = '';
    this.formD = '';
    this.formCorrect = 'a';
    this.formExplanation = '';
    this.formImageUrl = '';
    this.showForm.set(true);
  }

  closeForm(): void {
    this.showForm.set(false);
  }

  async saveVisible(visible: boolean): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.quizApi.saveLiveVisible(visible);
      this.liveVisible.set(visible);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar');
    } finally {
      this.saving.set(false);
    }
  }

  async saveSeason(): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.quizApi.saveSeasonInfo({
        startsOn: this.seasonStartsOn || null,
        message: this.seasonMessage || null,
      });
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar temporada');
    } finally {
      this.saving.set(false);
    }
  }

  async create(): Promise<void> {
    if (this.formPrompt.trim().length < 4) {
      this.error.set('Escribe el enunciado.');
      return;
    }
    if (![this.formA, this.formB, this.formC, this.formD].every((o) => o.trim())) {
      this.error.set('Rellena las cuatro opciones.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.quizApi.createQuestion({
        prompt: this.formPrompt,
        optionA: this.formA,
        optionB: this.formB,
        optionC: this.formC,
        optionD: this.formD,
        correctOption: this.formCorrect,
        explanation: this.formExplanation,
        imageUrl: this.formImageUrl || null,
      });
      this.closeForm();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo crear');
    } finally {
      this.saving.set(false);
    }
  }

  async onImageUpload(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    this.saving.set(true);
    try {
      this.formImageUrl = await this.quizApi.uploadQuestionImage(file);
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo subir');
    } finally {
      this.saving.set(false);
      input.value = '';
    }
  }

  async approve(q: QuizQuestion): Promise<void> {
    this.busyId.set(q.id);
    try {
      await this.quizApi.setQuestionStatus(q.id, 'approved');
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo aprobar');
    } finally {
      this.busyId.set(null);
    }
  }

  async reject(q: QuizQuestion): Promise<void> {
    const reason = prompt('Motivo del rechazo (opcional):') ?? undefined;
    this.busyId.set(q.id);
    try {
      await this.quizApi.setQuestionStatus(q.id, 'rejected', reason);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo rechazar');
    } finally {
      this.busyId.set(null);
    }
  }

  async launch(q: QuizQuestion, force = false): Promise<void> {
    if (
      !confirm(
        force
          ? '¿Forzar lanzamiento (cierra la ronda actual si hay una)?'
          : `¿Lanzar «${q.prompt.slice(0, 60)}…» en vivo?`,
      )
    ) {
      return;
    }
    this.busyId.set(q.id);
    try {
      await this.quizApi.launchRound(q.id, force);
      await this.reload();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'No se pudo lanzar';
      if (!force && message.toLowerCase().includes('live')) {
        if (confirm(`${message}\n\n¿Forzar lanzamiento?`)) {
          await this.launch(q, true);
          return;
        }
      }
      this.error.set(message);
    } finally {
      this.busyId.set(null);
    }
  }

  async closeLive(): Promise<void> {
    if (!confirm('¿Cerrar la ronda en vivo?')) return;
    this.saving.set(true);
    try {
      const n = await this.quizApi.closeLiveRound();
      alert(n ? 'Ronda cerrada.' : 'No había ronda abierta.');
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo cerrar');
    } finally {
      this.saving.set(false);
    }
  }

  async remove(q: QuizQuestion): Promise<void> {
    if (!confirm('¿Borrar esta pregunta?')) return;
    this.busyId.set(q.id);
    try {
      await this.quizApi.deleteQuestion(q.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo borrar');
    } finally {
      this.busyId.set(null);
    }
  }

  optionLabel(q: QuizQuestion, opt: QuizOption): string {
    switch (opt) {
      case 'a':
        return q.optionA;
      case 'b':
        return q.optionB;
      case 'c':
        return q.optionC;
      case 'd':
        return q.optionD;
    }
  }
}
