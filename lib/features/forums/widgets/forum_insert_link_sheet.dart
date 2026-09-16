import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../topic_detail_typography.dart';

class ForumLinkInsertResult {
  const ForumLinkInsertResult({required this.url, this.label});

  final String url;
  final String? label;
}

Future<ForumLinkInsertResult?> showForumInsertLinkSheet(
  BuildContext context, {
  String? initialUrl,
  String? initialLabel,
}) {
  return showModalBottomSheet<ForumLinkInsertResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ForumInsertLinkSheet(
      initialUrl: initialUrl,
      initialLabel: initialLabel,
    ),
  );
}

class _ForumInsertLinkSheet extends StatefulWidget {
  const _ForumInsertLinkSheet({this.initialUrl, this.initialLabel});

  final String? initialUrl;
  final String? initialLabel;

  @override
  State<_ForumInsertLinkSheet> createState() => _ForumInsertLinkSheetState();
}

class _ForumInsertLinkSheetState extends State<_ForumInsertLinkSheet> {
  late final TextEditingController _urlController;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _labelController = TextEditingController(text: widget.initialLabel ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _insert() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final label = _labelController.text.trim();
    Navigator.pop(
      context,
      ForumLinkInsertResult(
        url: url,
        label: label.isEmpty ? null : label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        cofradeoSheetBottomPadding(context) + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.burgundy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: AppColors.burgundy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Insertar enlace', style: TopicDetailTypography.title()),
                    Text(
                      'Pega la URL y, si quieres, un texto visible.',
                      style: AppTypography.bodyMedium(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: 'https://…',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.burgundy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _insert(),
            decoration: InputDecoration(
              labelText: 'Texto visible (opcional)',
              hintText: 'Ej. Consulta el cartel oficial',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.burgundy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _insert,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.textOnDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Insertar enlace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
