import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../quiz/data/quiz_repository.dart';
import '../../quiz/models/quiz_models.dart';
import '../../quiz/quiz_provider.dart';
import '../../quiz/utils/quiz_audio_limits.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';
import 'junta_quiz_create_sheet.dart';

class JuntaQuizTab extends ConsumerStatefulWidget {
  const JuntaQuizTab({super.key});

  @override
  ConsumerState<JuntaQuizTab> createState() => _JuntaQuizTabState();
}

class _JuntaQuizTabState extends ConsumerState<JuntaQuizTab> {
  var _busy = false;
  var _filter = _QuizListFilter.ready;
  var _authorsExpanded = false;
  Timer? _roundClock;

  @override
  void initState() {
    super.initState();
    _roundClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _roundClock?.cancel();
    super.dispose();
  }

  String _roundRemainingLabel(DateTime? closesAt) {
    if (closesAt == null) return 'Abierta hasta medianoche · 15 s al jugar';
    final left = closesAt.difference(DateTime.now());
    if (left.isNegative) return 'Caducada · cierra en cuanto puedas';
    final h = left.inHours;
    final m = left.inMinutes.remainder(60);
    if (h > 0) return 'Cierra a medianoche · quedan ${h}h ${m}min';
    return 'Cierra a medianoche · quedan $m min';
  }

  Future<void> _refresh() async {
    ref.invalidate(juntaQuizQuestionsProvider);
    ref.invalidate(juntaQuizLaunchedIdsProvider);
    ref.invalidate(quizLivePayloadProvider);
    ref.invalidate(quizAuthorIdsProvider);
    ref.invalidate(canCreateQuizQuestionsAsyncProvider);
    ref.invalidate(quizSeasonInfoProvider);
    ref.invalidate(quizLiveVisibleProvider);
  }

  Future<void> _setLiveVisible(bool visible) async {
    setState(() => _busy = true);
    try {
      await ref.read(quizRepositoryProvider).saveLiveVisible(visible);
      ref.invalidate(quizLiveVisibleProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              visible
                  ? 'Pregunta en vivo visible para todos'
                  : 'Pregunta en vivo oculta para los usuarios',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar. ¿Ejecutaste quiz_season_cleanup.sql? ($e)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAuthor({
    required String profileId,
    required bool enabled,
  }) async {
    setState(() => _busy = true);
    try {
      await ref.read(quizRepositoryProvider).setQuizAuthor(
            profileId: profileId,
            enabled: enabled,
          );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. ¿Ejecutaste quiz_authors.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteQuestion(QuizQuestion q, {required bool isLive}) async {
    if (isLive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cierra la ronda en vivo antes de borrar.'),
          ),
        );
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar pregunta?'),
        content: const Text(
          'Se eliminará la pregunta, sus rondas cerradas y la media '
          '(imagen/audio) del Storage. El ranking del mes no se toca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(quizRepositoryProvider).deleteQuestion(q.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pregunta eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo borrar. ¿Ejecutaste quiz_season_cleanup.sql? ($e)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanupMonth() async {
    final now = DateTime.now();
    final months = List.generate(8, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      final ym =
          '${d.year}-${d.month.toString().padLeft(2, '0')}';
      return ym;
    });
    var selected = months.length > 1 ? months[1] : months.first;

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Limpiar preguntas del mes'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Borra las preguntas creadas en ese mes y su media. '
                    'No toca el ranking. Las que estén en vivo se saltan.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: JuntaUi.inputDecoration(labelText: 'Mes'),
                    items: [
                      for (final m in months)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => selected = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentRed,
                  ),
                  child: const Text('Borrar mes'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(quizRepositoryProvider).deleteQuestionsForMonth(picked);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Borradas ${result.deleted}'
              '${result.skippedLive > 0 ? ' · ${result.skippedLive} en vivo omitidas' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo limpiar. ¿Ejecutaste quiz_season_cleanup.sql? ($e)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSeason() async {
    final repo = ref.read(quizRepositoryProvider);
    final current = await repo.fetchSeasonInfo();
    if (!mounted) return;

    var startsOn = current.startsOn;
    final messageCtrl = TextEditingController(text: current.message ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Temporada cofrade'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Se muestra en el quiz cuando no hay ronda en vivo.',
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startsOn ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setLocal(() => startsOn = picked);
                        }
                      },
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        startsOn == null
                            ? 'Elegir fecha de inicio'
                            : 'Inicio: ${startsOn!.day.toString().padLeft(2, '0')}/'
                                '${startsOn!.month.toString().padLeft(2, '0')}/'
                                '${startsOn!.year}',
                      ),
                    ),
                    if (startsOn != null) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => setLocal(() => startsOn = null),
                        child: const Text('Quitar fecha'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 3,
                      maxLength: 220,
                      decoration: JuntaUi.inputDecoration(
                        labelText: 'Mensaje (opcional)',
                        hintText: 'Ej. Arrancamos la liga del mes…',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    final message = messageCtrl.text;
    messageCtrl.dispose();
    if (saved != true) return;

    setState(() => _busy = true);
    try {
      await repo.saveSeasonInfo(
        startsOn: startsOn,
        message: message,
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporada guardada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar. ¿Ejecutaste quiz_season_cleanup.sql? ($e)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createQuestion() async {
    final draft = await showNewQuizQuestionSheet(context);
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(quizRepositoryProvider);
      final question = await repo.createQuestion(
        prompt: draft.prompt,
        optionA: draft.optionA,
        optionB: draft.optionB,
        optionC: draft.optionC,
        optionD: draft.optionD,
        correctOption: draft.correctOption,
        explanation: draft.explanation,
      );
      String? mediaError;
      final picked = draft.image;
      if (picked != null) {
        try {
          final bytes = await picked.readAsBytes();
          final mime = switch (picked.path.split('.').last.toLowerCase()) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };
          final url = await repo.uploadQuestionImage(
            questionId: question.id,
            bytes: bytes,
            mimeType: mime,
          );
          await repo.attachQuestionImage(
            questionId: question.id,
            imageUrl: url,
          );
        } on QuizImageTooLargeException {
          mediaError = 'La pregunta se guardó, pero la imagen supera 500 KB.';
        } catch (_) {
          mediaError =
              'La pregunta se guardó, pero la imagen falló. '
              '¿Ejecutaste quiz_fixes.sql (bucket quiz-images)?';
        }
      }
      final audio = draft.audio;
      if (audio != null) {
        try {
          final url = await repo.uploadQuestionAudio(
            questionId: question.id,
            bytes: audio.bytes,
            mimeType: audio.mimeType,
            extension: audio.extension,
          );
          await repo.attachQuestionAudio(
            questionId: question.id,
            audioUrl: url,
          );
        } on QuizAudioTooLargeException {
          mediaError =
              'La pregunta se guardó, pero el audio supera 1 MB.';
        } catch (_) {
          mediaError =
              'La pregunta se guardó, pero el audio falló. '
              '¿Ejecutaste quiz_audio.sql (bucket quiz-audio)?';
        }
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mediaError ?? 'Pregunta enviada a revisión',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo crear. ¿Ejecutaste quiz_daily.sql / quiz_authors.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(QuizQuestion q) async {
    setState(() => _busy = true);
    try {
      await ref.read(quizRepositoryProvider).setQuestionStatus(
            questionId: q.id,
            status: QuizQuestionStatus.approved,
          );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo aprobar')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(QuizQuestion q) async {
    setState(() => _busy = true);
    try {
      await ref.read(quizRepositoryProvider).setQuestionStatus(
            questionId: q.id,
            status: QuizQuestionStatus.rejected,
          );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo rechazar')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeLiveRound() async {
    setState(() => _busy = true);
    try {
      final n = await ref.read(quizRepositoryProvider).closeLiveRound();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n > 0 ? 'Ronda cerrada' : 'No había ninguna ronda en vivo',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo cerrar. ¿Ejecutaste quiz_fixes.sql? ($e)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachImage(QuizQuestion q) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(quizRepositoryProvider);
      final bytes = await file.readAsBytes();
      final mime = switch (file.path.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final url = await repo.uploadQuestionImage(
        questionId: q.id,
        bytes: bytes,
        mimeType: mime,
      );
      await repo.attachQuestionImage(questionId: q.id, imageUrl: url);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen guardada')),
        );
      }
    } on QuizImageTooLargeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen supera 500 KB.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo subir la imagen. ¿Ejecutaste quiz_fixes.sql? ($e)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachAudio(QuizQuestion q) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    if (bytes.length > QuizRepository.maxAudioBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El audio supera 1 MB.')),
        );
      }
      return;
    }
    final duration = await probeQuizAudioDuration(bytes);
    if (isQuizAudioTooLong(duration)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El audio no puede durar más de $quizMaxAudioSeconds segundos.',
            ),
          ),
        );
      }
      return;
    }

    final ext = (file.extension ?? 'm4a').toLowerCase();
    final mime = switch (ext) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'aac' => 'audio/aac',
      _ => 'audio/mp4',
    };

    setState(() => _busy = true);
    try {
      final repo = ref.read(quizRepositoryProvider);
      final url = await repo.uploadQuestionAudio(
        questionId: q.id,
        bytes: bytes,
        mimeType: mime,
        extension: ext,
      );
      await repo.attachQuestionAudio(questionId: q.id, audioUrl: url);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sonido guardado')),
        );
      }
    } on QuizAudioTooLargeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El audio supera 1 MB.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo subir el audio. ¿Ejecutaste quiz_audio.sql? ($e)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launch(QuizQuestion q, {bool force = false}) async {
    if (!force) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Lanzar ahora?'),
          content: const Text(
            'Se abrirá hasta medianoche de hoy (hora de España), se enviará '
            'push a quien tenga el aviso y el cronómetro personal será de '
            '15 segundos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanzar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(quizRepositoryProvider).launchRound(q.id, force: force);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pregunta en vivo!')),
        );
      }
    } catch (e) {
      final msg = e.toString();
      final stuck = msg.contains('Ya hay una pregunta en curso');
      if (stuck && mounted) {
        setState(() => _busy = false);
        final forceOk = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ya hay una en curso'),
            content: const Text(
              'Hay una ronda anterior sin cerrar (por eso el cronómetro '
              'aparece en 0 s). ¿Cerrar esa y lanzar esta ahora?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cerrar y lanzar'),
              ),
            ],
          ),
        );
        if (forceOk == true) {
          await _launch(q, force: true);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              stuck
                  ? 'Ejecuta quiz_fixes.sql y usa «Cerrar ronda».'
                  : 'No se pudo lanzar: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final canCreate =
        ref.watch(canCreateQuizQuestionsAsyncProvider).asData?.value ?? isAdmin;
    final questionsAsync = ref.watch(juntaQuizQuestionsProvider);
    final launchedIds =
        ref.watch(juntaQuizLaunchedIdsProvider).asData?.value ?? const <String>{};
    final assignmentsAsync = ref.watch(forumModeratorAssignmentsProvider);
    final authorIdsAsync = ref.watch(quizAuthorIdsProvider);
    final live = ref.watch(quizLivePayloadProvider).asData?.value;
    final hasLive = live?.isLive == true || live?.isAnswered == true;
    final liveQuestionId = live?.round?.questionId;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pregunta en vivo', style: JuntaUi.moduleTitle()),
                    const SizedBox(height: 2),
                    Text(
                      'Una al día · abierta hasta medianoche',
                      style: JuntaUi.caption(),
                    ),
                  ],
                ),
              ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: _busy ? null : _createQuestion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        if (isAdmin && hasLive) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LiveRoundBanner(
              prompt: live?.prompt ?? 'Pregunta activa',
              remainingLabel: _roundRemainingLabel(live?.round?.closesAt),
              busy: _busy,
              onClose: _closeLiveRound,
            ),
          ),
        ],
        if (isAdmin) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AuthorsPermissionPanel(
              expanded: _authorsExpanded,
              onExpansionChanged: (v) => setState(() => _authorsExpanded = v),
              assignmentsAsync: assignmentsAsync,
              authorIds: authorIdsAsync.asData?.value ?? {},
              busy: _busy,
              onToggle: (profileId, enabled) => _toggleAuthor(
                profileId: profileId,
                enabled: enabled,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LiveVisibilityPanel(
              visible:
                  ref.watch(quizLiveVisibleProvider).asData?.value ?? true,
              busy: _busy,
              onChanged: _setLiveVisible,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SeasonAndCleanupPanel(
              season: ref.watch(quizSeasonInfoProvider).asData?.value,
              busy: _busy,
              onEditSeason: _editSeason,
              onCleanupMonth: _cleanupMonth,
            ),
          ),
        ],
        const SizedBox(height: 8),
        questionsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (questions) {
            final counts = _QuizFilterCounts.from(questions, launchedIds);
            return Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _QuizListFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${f.label} (${counts.of(f)})'),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                          visualDensity: VisualDensity.compact,
                          selectedColor: AppColors.chipSelected,
                          labelStyle: JuntaUi.caption(
                            color: _filter == f
                                ? AppColors.chipSelectedText
                                : AppColors.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                          side: BorderSide(
                            color: _filter == f
                                ? AppColors.goldDark.withValues(alpha: 0.45)
                                : AppColors.border,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        Expanded(
          child: questionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error al cargar. ¿Ejecutaste quiz_daily.sql y quiz_authors.sql?',
                  style: JuntaUi.body(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (questions) {
              final filtered = _filterQuestions(questions, launchedIds);
              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      questions.isEmpty
                          ? (canCreate
                              ? 'Aún no hay preguntas. Crea la primera.'
                              : 'No tienes permiso para proponer preguntas.')
                          : 'No hay preguntas en «${_filter.label}».',
                      style: JuntaUi.emptyTitle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: JuntaUi.listPadding,
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: JuntaUi.itemGap),
                itemBuilder: (context, index) {
                  final q = filtered[index];
                  final used = launchedIds.contains(q.id);
                  final isCurrentLive = liveQuestionId == q.id;
                  return _QuizQuestionCard(
                    question: q,
                    used: used,
                    isCurrentLive: isCurrentLive,
                    isAdmin: isAdmin,
                    canCreate: canCreate,
                    busy: _busy,
                    onAttachImage: () => _attachImage(q),
                    onAttachAudio: () => _attachAudio(q),
                    onApprove: () => _approve(q),
                    onReject: () => _reject(q),
                    onLaunch: () => _launch(q),
                    onDelete: () => _deleteQuestion(q, isLive: isCurrentLive),
                  );
                },
              );
            },
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  List<QuizQuestion> _filterQuestions(
    List<QuizQuestion> questions,
    Set<String> launchedIds,
  ) {
    Iterable<QuizQuestion> list = questions;
    list = switch (_filter) {
      _QuizListFilter.all => list,
      _QuizListFilter.pending =>
        list.where((q) => q.status == QuizQuestionStatus.pendingReview),
      _QuizListFilter.ready => list.where(
          (q) =>
              q.status == QuizQuestionStatus.approved &&
              !launchedIds.contains(q.id),
        ),
      _QuizListFilter.used => list.where((q) => launchedIds.contains(q.id)),
      _QuizListFilter.rejected =>
        list.where((q) => q.status == QuizQuestionStatus.rejected),
    };

    final sorted = list.toList()
      ..sort((a, b) {
        int rank(QuizQuestion q) {
          if (q.status == QuizQuestionStatus.pendingReview) return 0;
          if (q.status == QuizQuestionStatus.approved &&
              !launchedIds.contains(q.id)) {
            return 1;
          }
          if (launchedIds.contains(q.id)) return 2;
          if (q.status == QuizQuestionStatus.rejected) return 3;
          return 4;
        }

        final c = rank(a).compareTo(rank(b));
        if (c != 0) return c;
        return (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0));
      });
    return sorted;
  }
}

enum _QuizListFilter { all, pending, ready, used, rejected }

extension on _QuizListFilter {
  String get label => switch (this) {
        _QuizListFilter.all => 'Todas',
        _QuizListFilter.pending => 'Revisión',
        _QuizListFilter.ready => 'Listas',
        _QuizListFilter.used => 'Ya lanzadas',
        _QuizListFilter.rejected => 'Rechazadas',
      };
}

class _QuizFilterCounts {
  const _QuizFilterCounts({
    required this.all,
    required this.pending,
    required this.ready,
    required this.used,
    required this.rejected,
  });

  factory _QuizFilterCounts.from(
    List<QuizQuestion> questions,
    Set<String> launchedIds,
  ) {
    var pending = 0;
    var ready = 0;
    var used = 0;
    var rejected = 0;
    for (final q in questions) {
      if (q.status == QuizQuestionStatus.pendingReview) pending++;
      if (q.status == QuizQuestionStatus.rejected) rejected++;
      if (launchedIds.contains(q.id)) {
        used++;
      } else if (q.status == QuizQuestionStatus.approved) {
        ready++;
      }
    }
    return _QuizFilterCounts(
      all: questions.length,
      pending: pending,
      ready: ready,
      used: used,
      rejected: rejected,
    );
  }

  final int all;
  final int pending;
  final int ready;
  final int used;
  final int rejected;

  int of(_QuizListFilter f) => switch (f) {
        _QuizListFilter.all => all,
        _QuizListFilter.pending => pending,
        _QuizListFilter.ready => ready,
        _QuizListFilter.used => used,
        _QuizListFilter.rejected => rejected,
      };
}

class _LiveRoundBanner extends StatelessWidget {
  const _LiveRoundBanner({
    required this.prompt,
    required this.remainingLabel,
    required this.busy,
    required this.onClose,
  });

  final String prompt;
  final String remainingLabel;
  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.burgundy.withValues(alpha: 0.10),
            AppColors.goldPale.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: AppColors.burgundy.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.burgundy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.burgundy),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.burgundy,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF6B6B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'EN VIVO',
                                  style: JuntaUi.caption(
                                    color: AppColors.textOnDark,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: busy ? null : onClose,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.burgundy,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prompt,
                        style: JuntaUi.cardTitle(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: AppColors.goldDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              remainingLabel,
                              style: JuntaUi.caption(
                                color: AppColors.goldDark,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorsPermissionPanel extends StatelessWidget {
  const _AuthorsPermissionPanel({
    required this.expanded,
    required this.onExpansionChanged,
    required this.assignmentsAsync,
    required this.authorIds,
    required this.busy,
    required this.onToggle,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final AsyncValue<List<ForumModeratorAssignment>> assignmentsAsync;
  final Set<String> authorIds;
  final bool busy;
  final void Function(String profileId, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          title: Text('Quién puede proponer', style: JuntaUi.sectionTitle()),
          subtitle: Text(
            'Moderadores con permiso de crear preguntas',
            style: JuntaUi.caption(),
          ),
          children: [
            assignmentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (_, _) => Text(
                'No se pudieron cargar moderadores.',
                style: JuntaUi.body(),
              ),
              data: (assignments) {
                final unique = <String, String>{};
                for (final a in assignments) {
                  unique.putIfAbsent(a.profileId, () => a.handle);
                }
                if (unique.isEmpty) {
                  return Text(
                    'Primero asigna moderadores en Moderadores.',
                    style: JuntaUi.caption(),
                  );
                }
                return Column(
                  children: [
                    for (final entry in unique.entries)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          '@${entry.value}',
                          style: JuntaUi.cardTitle(),
                        ),
                        subtitle: Text(
                          authorIds.contains(entry.key)
                              ? 'Puede proponer preguntas'
                              : 'Sin permiso de preguntas',
                          style: JuntaUi.caption(),
                        ),
                        value: authorIds.contains(entry.key),
                        activeThumbColor: AppColors.burgundy,
                        onChanged: busy
                            ? null
                            : (v) => onToggle(entry.key, v),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveVisibilityPanel extends StatelessWidget {
  const _LiveVisibilityPanel({
    required this.visible,
    required this.busy,
    required this.onChanged,
  });

  final bool visible;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.only(left: 0, right: 8),
        dense: true,
        title: Text('Mostrar Pregunta en vivo', style: JuntaUi.cardTitle()),
        subtitle: Text(
          visible
              ? 'El icono aparece en Foros y la gente puede entrar'
              : 'Oculto para usuarios. Junta sigue disponible',
          style: JuntaUi.caption(),
        ),
        value: visible,
        activeThumbColor: AppColors.burgundy,
        onChanged: busy ? null : onChanged,
      ),
    );
  }
}

class _SeasonAndCleanupPanel extends StatelessWidget {
  const _SeasonAndCleanupPanel({
    required this.busy,
    required this.onEditSeason,
    required this.onCleanupMonth,
    this.season,
  });

  final QuizSeasonInfo? season;
  final bool busy;
  final VoidCallback onEditSeason;
  final VoidCallback onCleanupMonth;

  @override
  Widget build(BuildContext context) {
    final starts = season?.startsOn;
    final msg = season?.message?.trim();
    final summary = starts == null && (msg == null || msg.isEmpty)
        ? 'Sin fecha ni mensaje todavía'
        : [
            if (starts != null)
              'Inicio ${starts.day.toString().padLeft(2, '0')}/'
                  '${starts.month.toString().padLeft(2, '0')}/'
                  '${starts.year}',
            if (msg != null && msg.isNotEmpty) 'con mensaje',
          ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Temporada cofrade', style: JuntaUi.cardTitle()),
          const SizedBox(height: 4),
          Text(summary, style: JuntaUi.caption()),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniAction(
                icon: Icons.flag_outlined,
                label: 'Editar temporada',
                onPressed: busy ? null : onEditSeason,
              ),
              _MiniAction(
                icon: Icons.delete_sweep_outlined,
                label: 'Limpiar mes',
                onPressed: busy ? null : onCleanupMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.question,
    required this.used,
    required this.isCurrentLive,
    required this.isAdmin,
    required this.canCreate,
    required this.busy,
    required this.onAttachImage,
    required this.onAttachAudio,
    required this.onApprove,
    required this.onReject,
    required this.onLaunch,
    required this.onDelete,
  });

  final QuizQuestion question;
  final bool used;
  final bool isCurrentLive;
  final bool isAdmin;
  final bool canCreate;
  final bool busy;
  final VoidCallback onAttachImage;
  final VoidCallback onAttachAudio;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onLaunch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final img = q.imageUrl?.trim();
    final hasImg = img != null && img.isNotEmpty;
    final hasAudio = q.hasAudio;
    final mediaBits = [
      if (hasImg) 'imagen',
      if (hasAudio) 'sonido',
    ];
    final mediaLabel =
        mediaBits.isEmpty ? 'sin media' : 'con ${mediaBits.join(' · ')}';
    final statusLabel = switch (q.status) {
      QuizQuestionStatus.pendingReview => 'Revisión',
      QuizQuestionStatus.approved => used
          ? (isCurrentLive ? 'En vivo' : 'Ya lanzada')
          : 'Lista',
      QuizQuestionStatus.rejected => 'Rechazada',
      QuizQuestionStatus.draft => 'Borrador',
    };
    final statusColor = switch (q.status) {
      QuizQuestionStatus.pendingReview => AppColors.goldDark,
      QuizQuestionStatus.approved =>
        isCurrentLive ? AppColors.burgundy : (used ? AppColors.textMuted : AppColors.burgundy),
      QuizQuestionStatus.rejected => AppColors.accentRed,
      QuizQuestionStatus.draft => AppColors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentLive
              ? AppColors.burgundy.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: hasImg
                      ? CofradeoNetworkImage(url: img, fit: BoxFit.cover)
                      : ColoredBox(
                          color: AppColors.surfaceAlt,
                          child: Icon(
                            Icons.image_outlined,
                            size: 22,
                            color: AppColors.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.prompt,
                      style: JuntaUi.cardTitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Correcta: ${q.correctOption.name.toUpperCase()} · '
                      '$mediaLabel',
                      style: JuntaUi.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: JuntaUi.caption(color: statusColor).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (isAdmin || canCreate) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniAction(
                  icon: Icons.image_outlined,
                  label: hasImg ? 'Imagen' : 'Añadir foto',
                  onPressed: busy ? null : onAttachImage,
                ),
                _MiniAction(
                  icon: hasAudio
                      ? Icons.graphic_eq_rounded
                      : Icons.music_note_outlined,
                  label: hasAudio ? 'Sonido' : 'Añadir audio',
                  onPressed: busy ? null : onAttachAudio,
                ),
                if (isAdmin &&
                    q.status == QuizQuestionStatus.pendingReview) ...[
                  _MiniAction(
                    icon: Icons.check_rounded,
                    label: 'Aprobar',
                    filled: true,
                    onPressed: busy ? null : onApprove,
                  ),
                  _MiniAction(
                    icon: Icons.close_rounded,
                    label: 'Rechazar',
                    onPressed: busy ? null : onReject,
                  ),
                ],
                if (isAdmin &&
                    q.status == QuizQuestionStatus.approved &&
                    !used)
                  _MiniAction(
                    icon: Icons.campaign_outlined,
                    label: 'Lanzar',
                    filled: true,
                    onPressed: busy ? null : onLaunch,
                  ),
                if (isAdmin &&
                    q.status == QuizQuestionStatus.approved &&
                    used &&
                    !isCurrentLive)
                  _MiniAction(
                    icon: Icons.replay_rounded,
                    label: 'Relanzar',
                    onPressed: busy ? null : onLaunch,
                  ),
                if (isAdmin && !isCurrentLive)
                  _MiniAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Borrar',
                    onPressed: busy ? null : onDelete,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.burgundy,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: JuntaUi.caption(color: AppColors.textOnDark).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        textStyle: JuntaUi.caption().copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
