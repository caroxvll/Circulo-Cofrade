import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../quiz/models/quiz_models.dart';
import '../../quiz/utils/quiz_audio_limits.dart';
import '../junta_ui.dart';

class NewQuizAudioDraft {
  const NewQuizAudioDraft({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.extension,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final String extension;
}

class NewQuizQuestionResult {
  const NewQuizQuestionResult({
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.explanation,
    this.image,
    this.audio,
  });

  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final QuizOption correctOption;
  final String? explanation;
  final XFile? image;
  final NewQuizAudioDraft? audio;
}

Future<NewQuizQuestionResult?> showNewQuizQuestionSheet(BuildContext context) {
  return showModalBottomSheet<NewQuizQuestionResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _NewQuizQuestionSheet(),
  );
}

class _NewQuizQuestionSheet extends StatefulWidget {
  const _NewQuizQuestionSheet();

  @override
  State<_NewQuizQuestionSheet> createState() => _NewQuizQuestionSheetState();
}

class _NewQuizQuestionSheetState extends State<_NewQuizQuestionSheet> {
  final _prompt = TextEditingController();
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();
  final _d = TextEditingController();
  final _explanation = TextEditingController();
  var _correct = QuizOption.a;
  XFile? _image;
  NewQuizAudioDraft? _audio;
  String? _error;

  @override
  void dispose() {
    _prompt.dispose();
    _a.dispose();
    _b.dispose();
    _c.dispose();
    _d.dispose();
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _image = file);
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'aac' => 'audio/aac',
      _ => 'audio/mp4',
    };
    if (bytes.length > 1024 * 1024) {
      if (mounted) {
        setState(() => _error = 'El audio no puede superar 1 MB (~15–20 s).');
      }
      return;
    }
    final duration = await probeQuizAudioDuration(bytes);
    if (isQuizAudioTooLong(duration)) {
      if (mounted) {
        setState(() {
          _error =
              'El audio no puede durar más de $quizMaxAudioSeconds segundos.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _audio = NewQuizAudioDraft(
        bytes: bytes,
        fileName: file.name,
        mimeType: mime,
        extension: ext.isEmpty ? 'm4a' : ext,
      );
    });
  }

  void _submit() {
    final prompt = _prompt.text.trim();
    final a = _a.text.trim();
    final b = _b.text.trim();
    final c = _c.text.trim();
    final d = _d.text.trim();
    if (prompt.isEmpty || a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
      setState(() => _error = 'Completa el enunciado y las cuatro opciones.');
      return;
    }
    Navigator.pop(
      context,
      NewQuizQuestionResult(
        prompt: prompt,
        optionA: a,
        optionB: b,
        optionC: c,
        optionD: d,
        correctOption: _correct,
        explanation: _explanation.text.trim().isEmpty
            ? null
            : _explanation.text.trim(),
        image: _image,
        audio: _audio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: maxH,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nueva pregunta',
                          style: JuntaUi.moduleTitle().copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Escribe el enunciado, las 4 respuestas y toca '
                          'la letra correcta.',
                          style: JuntaUi.body(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  _SectionCard(
                    title: '1 · Enunciado',
                    child: Column(
                      children: [
                        TextField(
                          controller: _prompt,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: JuntaUi.inputDecoration(
                            labelText: '¿Qué preguntas?',
                            hintText: 'Ej. ¿Cuántas espinas tiene…?',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ImagePickerTile(
                          hasImage: _image != null,
                          fileName: _image?.name,
                          onPick: _pickImage,
                          onClear: _image == null
                              ? null
                              : () => setState(() => _image = null),
                        ),
                        const SizedBox(height: 10),
                        _AudioPickerTile(
                          hasAudio: _audio != null,
                          fileName: _audio?.fileName,
                          onPick: _pickAudio,
                          onClear: _audio == null
                              ? null
                              : () => setState(() => _audio = null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '2 · Respuestas',
                    subtitle: 'Toca A, B, C o D para marcar la correcta',
                    child: Column(
                      children: [
                        for (final o in QuizOption.values) ...[
                          if (o != QuizOption.a) const SizedBox(height: 8),
                          _OptionRow(
                            option: o,
                            controller: switch (o) {
                              QuizOption.a => _a,
                              QuizOption.b => _b,
                              QuizOption.c => _c,
                              QuizOption.d => _d,
                            },
                            selected: _correct == o,
                            onSelect: () => setState(() => _correct = o),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '3 · Dato al revelar',
                    subtitle: 'Opcional · se muestra tras responder',
                    child: TextField(
                      controller: _explanation,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: JuntaUi.inputDecoration(
                        labelText: 'Explicación o curiosidad',
                        hintText: 'Un detalle cofrade para el final…',
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: JuntaUi.caption(color: AppColors.accentRed)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Enviar a revisión'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(title, style: JuntaUi.sectionTitle()),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: JuntaUi.caption()),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.controller,
    required this.selected,
    required this.onSelect,
  });

  final QuizOption option;
  final TextEditingController controller;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final letter = option.name.toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: selected ? AppColors.burgundy : AppColors.surfaceAlt,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onSelect,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  letter,
                  style: JuntaUi.cardTitle(
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Respuesta $letter',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: selected
                  ? AppColors.burgundy.withValues(alpha: 0.04)
                  : AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: selected
                      ? AppColors.burgundy.withValues(alpha: 0.45)
                      : AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: selected
                      ? AppColors.burgundy.withValues(alpha: 0.45)
                      : AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.burgundy,
                  width: 1.4,
                ),
              ),
              suffixIcon: selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.burgundy,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.hasImage,
    required this.onPick,
    this.fileName,
    this.onClear,
  });

  final bool hasImage;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: hasImage
          ? AppColors.burgundy.withValues(alpha: 0.06)
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  hasImage ? Icons.image_rounded : Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: AppColors.burgundy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasImage ? 'Imagen lista' : 'Añadir imagen',
                      style: JuntaUi.cardTitle(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasImage
                          ? (fileName ?? 'Toca para cambiar')
                          : 'Opcional · se ve al jugar',
                      style: JuntaUi.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasImage && onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPickerTile extends StatelessWidget {
  const _AudioPickerTile({
    required this.hasAudio,
    required this.onPick,
    this.fileName,
    this.onClear,
  });

  final bool hasAudio;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: hasAudio
          ? AppColors.burgundy.withValues(alpha: 0.06)
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  hasAudio
                      ? Icons.graphic_eq_rounded
                      : Icons.music_note_outlined,
                  size: 20,
                  color: AppColors.burgundy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAudio ? 'Sonido listo' : 'Añadir sonido',
                      style: JuntaUi.cardTitle(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAudio
                          ? (fileName ?? 'Toca para cambiar')
                          : 'Opcional · máx. $quizMaxAudioSeconds s · 1 MB · suena una vez',
                      style: JuntaUi.caption(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasAudio && onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
