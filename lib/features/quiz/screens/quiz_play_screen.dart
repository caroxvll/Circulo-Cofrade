import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../auth/auth_provider.dart';
import '../../forums/forum_topics_typography.dart';
import '../data/quiz_repository.dart';
import '../models/quiz_models.dart';
import '../quiz_provider.dart';

class QuizPlayScreen extends ConsumerStatefulWidget {
  const QuizPlayScreen({super.key});

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  var _opening = false;
  var _submitting = false;
  var _userWantsStart = false;
  var _forfeitStarted = false;
  DateTime? _openedAt;
  int _secondsLeft = 15;
  Timer? _timer;
  QuizSubmitResult? _result;
  String? _error;
  String? _activeRoundId;
  QuizOption? _pressed;
  /// Capturado al abrir: no usar [ref] en [dispose].
  QuizRepository? _quizRepo;
  final AudioPlayer _audioPlayer = AudioPlayer();
  /// Una sola reproducción por ronda; no se reescucha (anti-trampa).
  var _audioConsumed = false;
  var _audioPlaying = false;
  var _audioSilenced = false;
  var _hasQuestionAudio = false;
  StreamSubscription<void>? _audioCompleteSub;

  /// Tras Empezar y sin resultado: salir cuenta como fallo.
  bool get _shouldBlockLeave =>
      _openedAt != null && _result == null;

  Future<void> _stopQuestionAudio({bool permanent = true}) async {
    if (permanent) {
      _audioConsumed = true;
      _audioSilenced = true;
      _audioPlaying = false;
    }
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> _silenceAudioForever() async {
    if (!_hasQuestionAudio || _audioSilenced) return;
    await _stopQuestionAudio(permanent: true);
    if (mounted) setState(() {});
  }

  Future<void> _playQuestionAudioOnce(String? url) async {
    if (_audioConsumed) return;
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    _audioConsumed = true;
    _hasQuestionAudio = true;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(trimmed));
      if (mounted) {
        setState(() {
          _audioPlaying = true;
          _audioSilenced = false;
        });
      }
    } catch (_) {
      // Silencio si el clip falla: la pregunta sigue jugable.
      if (mounted) {
        setState(() {
          _audioPlaying = false;
          _audioSilenced = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _audioPlaying = false;
        _audioConsumed = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audioCompleteSub?.cancel() ?? Future.value());
    unawaited(_stopQuestionAudio());
    unawaited(_audioPlayer.dispose());
    // Salida forzada (otra ruta / dispose): abandona si ya había empezado.
    final roundId = _activeRoundId;
    final repo = _quizRepo;
    if (roundId != null &&
        repo != null &&
        _openedAt != null &&
        _result == null &&
        !_forfeitStarted) {
      _forfeitStarted = true;
      unawaited(repo.forfeitRound(roundId).catchError((_) => null));
    }
    super.dispose();
  }

  Future<void> _forfeitAndLeave() async {
    final roundId = _activeRoundId;
    if (roundId == null || _result != null || _forfeitStarted) {
      if (mounted) context.pop();
      return;
    }
    _forfeitStarted = true;
    _timer?.cancel();
    unawaited(_stopQuestionAudio());
    setState(() => _submitting = true);
    try {
      final QuizRepository repo =
          _quizRepo ?? ref.read(quizRepositoryProvider);
      _quizRepo = repo;
      final result = await repo.forfeitRound(roundId);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _result = result;
          _submitting = false;
        });
        ref.invalidate(quizLivePayloadProvider);
        ref.invalidate(quizMonthlyLeaderboardProvider);
      } else if (mounted) {
        context.pop();
      }
    } catch (_) {
      _forfeitStarted = false;
      if (!mounted) return;
      setState(() => _submitting = false);
      context.pop();
    }
  }

  /// Sin diálogo: salir tras Empezar = fallo inmediato (anti-trampa).
  Future<void> _onLeaveAttempt() async {
    if (!_shouldBlockLeave) {
      if (mounted) context.pop();
      return;
    }
    await _forfeitAndLeave();
  }

  void _startTimer(int answerSeconds, DateTime openedAt, String roundId) {
    _timer?.cancel();
    _openedAt = openedAt;
    _activeRoundId = roundId;
    final elapsed = DateTime.now().difference(openedAt).inMilliseconds / 1000;
    final left = answerSeconds - elapsed;
    _secondsLeft = left.ceil().clamp(0, answerSeconds);

    if (left <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submitTimeout(roundId);
      });
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _openedAt == null) return;
      final e = DateTime.now().difference(_openedAt!).inMilliseconds / 1000;
      final rem = answerSeconds - e;
      setState(() {
        _secondsLeft = rem.ceil().clamp(0, answerSeconds);
      });
      if (rem <= 0) {
        _timer?.cancel();
        _submitTimeout(roundId);
      }
    });
  }

  Future<void> _submitTimeout(String roundId) async {
    if (_submitting || _result != null) return;
    await _submit(roundId, QuizOption.a, isTimeout: true);
  }

  Future<void> _ensureOpen(QuizLivePayload payload) async {
    final round = payload.round;
    if (round == null || _opening || _result != null) return;
    if (payload.answer?.hasAnswered == true) return;
    if (_openedAt != null && _activeRoundId == round.id) return;

    final existingOpen = payload.answer?.openedAt;
    if (existingOpen != null) {
      _quizRepo ??= ref.read(quizRepositoryProvider);
      _startTimer(round.answerSeconds, existingOpen, round.id);
      // Reentrada: no se vuelve a reproducir el audio (anti-trampa).
      final hadAudio = payload.hasAudio;
      setState(() {
        _userWantsStart = true;
        _hasQuestionAudio = hadAudio;
        if (hadAudio) {
          _audioConsumed = true;
          _audioSilenced = true;
          _audioPlaying = false;
        }
      });
      return;
    }

    setState(() {
      _opening = true;
      _userWantsStart = true;
      _error = null;
    });
    try {
      final repo = ref.read(quizRepositoryProvider);
      _quizRepo = repo;
      final openedAt = await repo.openRound(round.id);
      if (!mounted) return;
      _startTimer(round.answerSeconds, openedAt, round.id);
      final hadAudio = payload.hasAudio;
      if (hadAudio) {
        setState(() => _hasQuestionAudio = true);
        unawaited(_playQuestionAudioOnce(payload.audioUrl));
      }
      setState(() => _opening = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _userWantsStart = false;
        _error = 'No se pudo iniciar la pregunta. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _submit(
    String roundId,
    QuizOption option, {
    bool isTimeout = false,
  }) async {
    if (_submitting || _result != null) return;
    setState(() {
      _submitting = true;
      _pressed = option;
      _error = null;
    });
    try {
      final result = await ref.read(quizRepositoryProvider).submitAnswer(
            roundId: roundId,
            option: option,
          );
      _timer?.cancel();
      unawaited(_stopQuestionAudio());
      if (!mounted) return;
      setState(() {
        _result = result.copyWith(timedOut: isTimeout);
        _submitting = false;
        if (isTimeout) _secondsLeft = 0;
      });
      ref.invalidate(quizLivePayloadProvider);
      ref.invalidate(quizMonthlyLeaderboardProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pressed = null;
        _error = isTimeout
            ? 'Se acabó el tiempo.'
            : 'No se pudo enviar la respuesta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveVisible =
        ref.watch(quizLiveVisibleProvider).asData?.value ?? true;
    if (!liveVisible) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Pregunta en vivo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 40,
                  color: AppColors.goldDark.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pregunta en vivo no disponible',
                  style: AppTypography.displaySmall(color: AppColors.burgundy)
                      .copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Esta sección está desactivada por ahora. '
                  'Vuelve más adelante.',
                  style: AppTypography.bodyMedium(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isAuthed = ref.watch(isAuthenticatedProvider);
    if (!isAuthed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Pregunta en vivo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'El reto cofrade del momento',
                  style: AppTypography.displaySmall(color: AppColors.burgundy)
                      .copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Inicia sesión para responder la pregunta en vivo '
                  'y sumar puntos al ranking.',
                  style: AppTypography.bodyMedium(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push(
                    '/login?redirect=${Uri.encodeComponent('/quiz')}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                  ),
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final liveAsync = ref.watch(quizLivePayloadProvider);

    return PopScope(
      canPop: !_shouldBlockLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onLeaveAttempt());
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pregunta en vivo'),
        actions: [
          TextButton(
            onPressed: _shouldBlockLeave
                ? () => unawaited(_onLeaveAttempt())
                : () => context.push('/quiz/ranking'),
            child: const Text('Ranking'),
          ),
        ],
      ),
      body: liveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'No se pudo cargar la pregunta.\n¿Ejecutaste quiz_daily.sql?',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
        data: (payload) {
          if (payload.isIdle) {
            final season = ref.watch(quizSeasonInfoProvider).asData?.value;
            return _IdleState(
              onRanking: () => context.push('/quiz/ranking'),
              season: season,
            );
          }

          if (payload.isAnswered || _result != null) {
            final result = _result;
            final answer = payload.answer;
            final isCorrect = result?.isCorrect ?? answer?.isCorrect ?? false;
            final score = result?.score ?? answer?.score ?? 0;
            final correct = result?.correctOption ?? answer?.correctOption;
            final selected = result?.selectedOption ?? answer?.selectedOption;
            final explanation = result?.explanation ?? payload.explanation;

            return _ResultView(
              prompt: payload.prompt ?? '',
              imageUrl: payload.imageUrl,
              isCorrect: isCorrect,
              score: score,
              explanation: explanation,
              optionA: payload.optionA ?? '',
              optionB: payload.optionB ?? '',
              optionC: payload.optionC ?? '',
              optionD: payload.optionD ?? '',
              correctOption: correct,
              selectedOption: selected,
              forfeited: result?.forfeited ?? false,
              timedOut: result?.timedOut ?? false,
              onRanking: () => context.push('/quiz/ranking'),
            );
          }

          final round = payload.round!;
          final alreadyOpened = payload.answer?.openedAt != null;
          final inPlay = _openedAt != null || alreadyOpened;

          // Si ya había empezado (reentrada), reanuda el cronómetro.
          if (alreadyOpened && _openedAt == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _ensureOpen(payload);
            });
          }

          // Antes de Empezar: no se abre la ronda ni corre el tiempo.
          if (!inPlay && !_userWantsStart) {
            final img = payload.imageUrl?.trim();
            return _ReadyToPlayState(
              answerSeconds: round.answerSeconds,
              hasAudio: payload.hasAudio,
              hasImage: img != null && img.isNotEmpty,
              error: _error,
              onStart: () => _ensureOpen(payload),
            );
          }

          if (_opening && _openedAt == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final imageUrl = payload.imageUrl?.trim();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              _PlayHeader(
                secondsLeft: _secondsLeft,
                total: round.answerSeconds,
                showAudioControls: _hasQuestionAudio,
                audioPlaying: _audioPlaying && !_audioSilenced,
                audioLocked: _audioSilenced || (!_audioPlaying && _audioConsumed),
                onSilence: _silenceAudioForever,
              ),
              const SizedBox(height: 20),
              Text(
                payload.prompt ?? '',
                style: AppTypography.titleLarge(color: AppColors.textPrimary)
                    .copyWith(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                _QuizImage(url: imageUrl),
              ],
              const SizedBox(height: 20),
              Text(
                'Elige una respuesta',
                style: AppTypography.labelSmall(color: AppColors.textMuted)
                    .copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final option in QuizOption.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionButton(
                    letter: option.name.toUpperCase(),
                    label: switch (option) {
                      QuizOption.a => payload.optionA ?? '',
                      QuizOption.b => payload.optionB ?? '',
                      QuizOption.c => payload.optionC ?? '',
                      QuizOption.d => payload.optionD ?? '',
                    },
                    enabled: !_submitting && _secondsLeft > 0,
                    selected: _pressed == option,
                    onTap: () => _submit(round.id, option),
                  ),
                ),
              if (_secondsLeft <= 0 && _result == null && !_submitting)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tiempo agotado…',
                    style: AppTypography.bodyMedium(color: AppColors.accentRed),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTypography.bodyMedium(color: AppColors.accentRed),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
    ),
    );
  }
}

class _PlayHeader extends StatelessWidget {
  const _PlayHeader({
    required this.secondsLeft,
    required this.total,
    this.showAudioControls = false,
    this.audioPlaying = false,
    this.audioLocked = false,
    this.onSilence,
  });

  final int secondsLeft;
  final int total;
  final bool showAudioControls;
  final bool audioPlaying;
  final bool audioLocked;
  final VoidCallback? onSilence;

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 5;
    final progress = total == 0 ? 0.0 : (secondsLeft / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.burgundy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _TimerRing(
            secondsLeft: secondsLeft,
            progress: progress,
            urgent: urgent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: urgent
                            ? AppColors.accentRed
                            : AppColors.burgundy,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EN VIVO',
                      style: AppTypography.labelSmall(
                        color: AppColors.burgundy,
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    if (showAudioControls)
                      _AudioOnceControl(
                        playing: audioPlaying,
                        locked: audioLocked,
                        onSilence: onSilence,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  urgent ? '¡Date prisa!' : 'Responde antes de que acabe',
                  style: AppTypography.bodyMedium(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 13),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    color: urgent ? AppColors.accentRed : AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioOnceControl extends StatelessWidget {
  const _AudioOnceControl({
    required this.playing,
    required this.locked,
    this.onSilence,
  });

  final bool playing;
  final bool locked;
  final VoidCallback? onSilence;

  @override
  Widget build(BuildContext context) {
    if (locked || !playing) {
      return Tooltip(
        message: 'El audio solo suena una vez',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_off_outlined,
              size: 16,
              color: AppColors.textMuted.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 4),
            Text(
              'Sin replay',
              style: AppTypography.labelSmall(color: AppColors.textMuted)
                  .copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return IconButton(
      tooltip: 'Silenciar (no se puede volver a oír)',
      onPressed: onSilence,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: const Icon(Icons.volume_up_rounded, size: 20),
      color: AppColors.burgundy,
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.secondsLeft,
    required this.progress,
    required this.urgent,
  });

  final int secondsLeft;
  final double progress;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.accentRed : AppColors.goldDark;
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: color,
          track: AppColors.border,
        ),
        child: Center(
          child: Text(
            '$secondsLeft',
            style: AppTypography.displaySmall(color: color).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _QuizImage extends StatelessWidget {
  const _QuizImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: CofradeoNetworkImage(url: url, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.letter,
    required this.label,
    required this.onTap,
    required this.enabled,
    this.selected = false,
    this.state = _OptionVisual.neutral,
  });

  final String letter;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool selected;
  final _OptionVisual state;

  @override
  Widget build(BuildContext context) {
    final (bg, border, letterBg, letterFg, textColor) = switch (state) {
      _OptionVisual.correct => (
          const Color(0xFF1B5E20).withValues(alpha: 0.08),
          const Color(0xFF2E7D32),
          const Color(0xFF2E7D32),
          Colors.white,
          AppColors.textPrimary,
        ),
      _OptionVisual.wrong => (
          AppColors.accentRed.withValues(alpha: 0.08),
          AppColors.accentRed,
          AppColors.accentRed,
          Colors.white,
          AppColors.textPrimary,
        ),
      _OptionVisual.muted => (
          AppColors.surfaceAlt,
          AppColors.border,
          AppColors.border,
          AppColors.textMuted,
          AppColors.textMuted,
        ),
      _OptionVisual.neutral => (
          selected
              ? AppColors.burgundy.withValues(alpha: 0.06)
              : AppColors.surface,
          selected
              ? AppColors.burgundy.withValues(alpha: 0.45)
              : AppColors.border,
          selected ? AppColors.burgundy : AppColors.burgundy,
          Colors.white,
          AppColors.textPrimary,
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      elevation: state == _OptionVisual.neutral && !selected ? 0 : 0,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected || state != _OptionVisual.neutral ? 1.4 : 1),
            boxShadow: state == _OptionVisual.neutral
                ? [
                    BoxShadow(
                      color: AppColors.burgundy.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: letterBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: AppTypography.labelSmall(color: letterFg).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLarge(color: textColor).copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
              if (state == _OptionVisual.correct)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32), size: 22)
              else if (state == _OptionVisual.wrong)
                const Icon(Icons.cancel_rounded,
                    color: AppColors.accentRed, size: 22)
              else if (selected)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OptionVisual { neutral, correct, wrong, muted }

class _ReadyToPlayState extends StatelessWidget {
  const _ReadyToPlayState({
    required this.answerSeconds,
    required this.onStart,
    this.hasAudio = false,
    this.hasImage = false,
    this.error,
  });

  final int answerSeconds;
  final VoidCallback onStart;
  final bool hasAudio;
  final bool hasImage;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.gold.withValues(alpha: 0.28),
                        AppColors.burgundy.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '?',
                    style: AppTypography.displaySmall(color: AppColors.burgundy)
                        .copyWith(
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'La pregunta del día está lista',
                  style: AppTypography.displaySmall(color: AppColors.burgundy)
                      .copyWith(fontSize: 22, height: 1.15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ReadyMediaChip(
                      icon: hasImage
                          ? Icons.image_rounded
                          : Icons.hide_image_outlined,
                      label: hasImage ? 'Con imagen' : 'Sin imagen',
                      active: hasImage,
                    ),
                    _ReadyMediaChip(
                      icon: hasAudio
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_outlined,
                      label: hasAudio ? 'Con sonido' : 'Sin sonido',
                      active: hasAudio,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Cuando pulses Empezar, tendrás $answerSeconds segundos '
                  'para responder. Hasta entonces el tiempo no corre.',
                  style: AppTypography.bodyMedium(color: AppColors.textMuted)
                      .copyWith(fontSize: 14.5, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                if (hasAudio) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: AppColors.goldDark.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sube el volumen: el audio suena una sola vez '
                            'al Empezar (no se puede repetir).',
                            style: AppTypography.bodyMedium(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 13.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.burgundy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.burgundy.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: AppColors.burgundy.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Si sales después de Empezar, cuenta como fallo '
                          '(-40 puntos) y no podrás volver a intentar.',
                          style: AppTypography.bodyMedium(
                            color: AppColors.textSecondary,
                          ).copyWith(fontSize: 13.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    error!,
                    style: AppTypography.bodyMedium(color: AppColors.accentRed),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Spacer(flex: 3),
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Empezar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadyMediaChip extends StatelessWidget {
  const _ReadyMediaChip({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.burgundy : AppColors.textMuted;
    final bg = active
        ? AppColors.burgundy.withValues(alpha: 0.08)
        : AppColors.surfaceAlt;
    final border = active
        ? AppColors.burgundy.withValues(alpha: 0.28)
        : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodyMedium(color: fg).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState({required this.onRanking, this.season});

  final VoidCallback onRanking;
  final QuizSeasonInfo? season;

  String? _seasonDateLabel(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final seasonInfo = season;
    final showSeason = seasonInfo != null && seasonInfo.hasContent;
    final msg = seasonInfo?.message?.trim();
    final startsOn = seasonInfo?.startsOn;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _QuizAboutHero(),
                const Spacer(flex: 2),
                _QuizAboutSection(
                  icon: Icons.menu_book_outlined,
                  title: 'Descripción',
                  child: Text(
                    'Es el reto diario de Círculo Cofrade: una pregunta '
                    'rápida sobre hermandades y cultura cofrade. Respondes '
                    'en segundos y sumas al ranking del mes.\n\n'
                    'Lo organizamos desde la app (no es la Junta de '
                    'Hermandades oficial).',
                    style: ForumTopicsTypography.style(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ).copyWith(fontSize: 12.5),
                  ),
                ),
                const Spacer(),
                _QuizAboutSection(
                  icon: Icons.bolt_outlined,
                  title: 'Cómo funciona',
                  child: const Column(
                    children: [
                      _QuizAboutRuleRow(
                        icon: Icons.notifications_active_outlined,
                        text:
                            'Con el aviso activado, te enteras al instante.',
                      ),
                      SizedBox(height: 6),
                      _QuizAboutRuleRow(
                        icon: Icons.timer_outlined,
                        text:
                            '15 segundos, una pregunta y cuatro opciones.',
                      ),
                      SizedBox(height: 6),
                      _QuizAboutRuleRow(
                        icon: Icons.graphic_eq_outlined,
                        text:
                            'A veces lleva imagen o sonido de Semana Santa.',
                      ),
                      SizedBox(height: 6),
                      _QuizAboutRuleRow(
                        icon: Icons.emoji_events_outlined,
                        text: 'Los aciertos suman al marcador mensual.',
                      ),
                    ],
                  ),
                ),
                if (showSeason) ...[
                  const Spacer(),
                  _QuizAboutSection(
                    icon: Icons.flag_outlined,
                    title: 'Temporada cofrade',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (startsOn != null) ...[
                          Text(
                            seasonInfo.startsInFuture
                                ? 'Empieza el ${_seasonDateLabel(startsOn)}.'
                                : 'Arrancó el ${_seasonDateLabel(startsOn)}.',
                            style: ForumTopicsTypography.style(
                              color: AppColors.burgundy,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ).copyWith(fontSize: 13),
                          ),
                          if (msg != null && msg.isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if (msg != null && msg.isNotEmpty)
                          Text(
                            msg,
                            style: ForumTopicsTypography.style(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                            ).copyWith(fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                _QuizAboutSection(
                  icon: Icons.schedule_outlined,
                  title: 'Ahora mismo',
                  showDivider: false,
                  child: Text(
                    'Hoy aún no hay ronda en vivo. Cuando se publique la '
                    'pregunta del día, te avisaremos si tienes las '
                    'notificaciones activadas.',
                    style: ForumTopicsTypography.style(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ).copyWith(fontSize: 12.5),
                  ),
                ),
                const Spacer(flex: 2),
                OutlinedButton(
                  onPressed: onRanking,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Ver ranking del mes'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizAboutHero extends StatelessWidget {
  const _QuizAboutHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundyDark.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Image.asset(
              AppAssets.quizLiveLogo,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'INFORMACIÓN DEL RETO',
          style: AppTypography.screenTitle(color: AppColors.goldDark)
              .copyWith(fontSize: 18, letterSpacing: 0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          'PREGUNTA EN VIVO',
          style: AppTypography.displaySmall(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 15, letterSpacing: 0.35),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'El reto diario de Círculo Cofrade.',
          style: ForumTopicsTypography.style(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ).copyWith(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuizAboutSection extends StatelessWidget {
  const _QuizAboutSection({
    required this.icon,
    required this.title,
    required this.child,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.burgundy),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: AppTypography.displaySmall(color: AppColors.burgundy)
                  .copyWith(fontSize: 13.5, letterSpacing: 0.4),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (showDivider) const Divider(height: 18, color: AppColors.border),
      ],
    );
  }
}

class _QuizAboutRuleRow extends StatelessWidget {
  const _QuizAboutRuleRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.goldDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: ForumTopicsTypography.style(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ).copyWith(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.prompt,
    required this.imageUrl,
    required this.isCorrect,
    required this.score,
    required this.explanation,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.selectedOption,
    required this.onRanking,
    this.forfeited = false,
    this.timedOut = false,
  });

  final String prompt;
  final String? imageUrl;
  final bool isCorrect;
  final int score;
  final String? explanation;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final QuizOption? correctOption;
  final QuizOption? selectedOption;
  final VoidCallback onRanking;
  final bool forfeited;
  final bool timedOut;

  String _label(QuizOption o) => switch (o) {
        QuizOption.a => optionA,
        QuizOption.b => optionB,
        QuizOption.c => optionC,
        QuizOption.d => optionD,
      };

  _OptionVisual _visualFor(QuizOption o) {
    final isRight = correctOption == o;
    final isPicked = selectedOption == o;
    if (isRight) return _OptionVisual.correct;
    if (isPicked && !isCorrect && !forfeited && !timedOut) {
      return _OptionVisual.wrong;
    }
    return _OptionVisual.muted;
  }

  @override
  Widget build(BuildContext context) {
    final accent = isCorrect ? const Color(0xFF2E7D32) : AppColors.accentRed;
    final img = imageUrl?.trim();
    final title = isCorrect
        ? '¡Correcto!'
        : forfeited
            ? 'Has salido'
            : timedOut
                ? 'Tiempo agotado'
                : 'Casi…';
    final subtitle = isCorrect
        ? 'Suma al ranking del mes'
        : forfeited
            ? 'Abandono · no puedes reintentar'
            : timedOut
                ? 'Se acabó el tiempo'
                : 'La correcta está marcada abajo';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCorrect
                  ? [
                      const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      AppColors.goldPale.withValues(alpha: 0.45),
                    ]
                  : [
                      AppColors.accentRed.withValues(alpha: 0.10),
                      AppColors.goldPale.withValues(alpha: 0.35),
                    ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  isCorrect
                      ? Icons.check_rounded
                      : forfeited
                          ? Icons.exit_to_app_rounded
                          : timedOut
                              ? Icons.timer_off_outlined
                              : Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTypography.displaySmall(color: accent).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                score >= 0 ? '+$score pts' : '$score pts',
                style: AppTypography.displayMedium(color: AppColors.burgundy)
                    .copyWith(fontSize: 34, height: 1.05),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          prompt,
          style: AppTypography.titleLarge(color: AppColors.textPrimary)
              .copyWith(fontSize: 17, height: 1.3, fontWeight: FontWeight.w600),
        ),
        if (img != null && img.isNotEmpty) ...[
          const SizedBox(height: 14),
          _QuizImage(url: img),
        ],
        const SizedBox(height: 18),
        Text(
          'RESULTADO',
          style: AppTypography.labelSmall(color: AppColors.textMuted).copyWith(
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final option in QuizOption.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              letter: option.name.toUpperCase(),
              label: _label(option),
              enabled: false,
              state: _visualFor(option),
              onTap: () {},
            ),
          ),
        if (explanation != null && explanation!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: AppColors.goldDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dato cofrade',
                      style: AppTypography.labelSmall(color: AppColors.goldDark)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  explanation!,
                  style: AppTypography.bodyLarge().copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: onRanking,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.burgundy,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Ver ranking del mes'),
        ),
      ],
    );
  }
}
