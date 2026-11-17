import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/topic_poll.dart';

/// Bloque opcional para adjuntar una encuesta al crear un tema.
class TopicPollComposeSection extends StatelessWidget {
  const TopicPollComposeSection({
    super.key,
    required this.enabled,
    required this.active,
    required this.questionController,
    required this.optionControllers,
    required this.onToggle,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  final bool enabled;
  final bool active;
  final TextEditingController questionController;
  final List<TextEditingController> optionControllers;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;

  static const minOptions = 2;
  static const maxOptions = 6;

  /// Valida y devuelve el borrador, o un mensaje de error.
  static ({TopicPollDraft? draft, String? error}) validate({
    required bool active,
    required String question,
    required List<String> options,
  }) {
    if (!active) return (draft: null, error: null);

    final q = question.trim();
    if (q.length < 5) {
      return (draft: null, error: 'La pregunta de la encuesta debe tener al menos 5 caracteres.');
    }
    if (q.length > 200) {
      return (draft: null, error: 'La pregunta de la encuesta no puede superar 200 caracteres.');
    }

    final cleaned = options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    if (cleaned.length < minOptions) {
      return (draft: null, error: 'La encuesta necesita al menos 2 opciones.');
    }
    if (cleaned.length > maxOptions) {
      return (draft: null, error: 'Máximo 6 opciones en la encuesta.');
    }
    for (final o in cleaned) {
      if (o.length > 80) {
        return (draft: null, error: 'Cada opción puede tener como máximo 80 caracteres.');
      }
    }

    return (draft: TopicPollDraft(question: q, options: cleaned), error: null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: active,
          onChanged: enabled ? onToggle : null,
          title: Text(
            'Añadir encuesta',
            style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Opcional · solo tú puedes crearla al publicar el tema',
            style: AppTypography.bodyMedium(color: AppColors.textMuted)
                .copyWith(fontSize: 12.5, height: 1.25),
          ),
          activeThumbColor: AppColors.burgundy,
        ),
        if (active) ...[
          const SizedBox(height: 4),
          TextField(
            controller: questionController,
            enabled: enabled,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Pregunta',
              hintText: '¿Qué opináis…?',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < optionControllers.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: optionControllers[i],
                    enabled: enabled,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: 'Opción ${i + 1}',
                      counterText: '',
                    ),
                  ),
                ),
                if (optionControllers.length > minOptions)
                  IconButton(
                    onPressed: enabled ? () => onRemoveOption(i) : null,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Quitar opción',
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (optionControllers.length < maxOptions)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: enabled ? onAddOption : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir opción'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.burgundy,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
