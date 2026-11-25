import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_quill_markdown.dart';

/// Editor de una hoja: título, negrita y cursiva, con la letra del libro.
class HistoriaPageEditor extends StatefulWidget {
  const HistoriaPageEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.hintText,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? hintText;

  @override
  State<HistoriaPageEditor> createState() => _HistoriaPageEditorState();
}

class _HistoriaPageEditorState extends State<HistoriaPageEditor> {
  late final QuillController _quill;
  late final FocusNode _focus;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _quill = QuillController(
      document: forumMarkdownToDocument(widget.controller.text),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quill.addListener(_onQuillChanged);
  }

  @override
  void dispose() {
    _quill.removeListener(_onQuillChanged);
    _quill.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQuillChanged() {
    if (_syncing) return;
    _syncing = true;
    final md = forumDocumentToMarkdown(_quill.document);
    if (widget.controller.text != md) {
      widget.controller.value = widget.controller.value.copyWith(
        text: md,
        selection: TextSelection.collapsed(offset: md.length),
      );
    }
    _syncing = false;
    if (mounted) setState(() {});
  }

  bool _has(Attribute attribute) {
    final current = _quill.getSelectionStyle().attributes[attribute.key];
    if (current == null) return false;
    if (attribute.value == true) return current.value == true;
    return current.value == attribute.value;
  }

  void _toggle(Attribute attribute) {
    if (!widget.enabled) return;
    if (_has(attribute)) {
      _quill.formatSelection(Attribute.clone(attribute, null));
    } else {
      _quill.formatSelection(attribute);
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.bookBody();
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormatBar(
              titleOn: _has(Attribute.h2),
              boldOn: _has(Attribute.bold),
              italicOn: _has(Attribute.italic),
              onTitle: () => _toggle(Attribute.h2),
              onBold: () => _toggle(Attribute.bold),
              onItalic: () => _toggle(Attribute.italic),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F1E6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: QuillEditor.basic(
                    controller: _quill,
                    focusNode: _focus,
                    config: QuillEditorConfig(
                      placeholder: widget.hintText ?? 'Escribe esta página…',
                      padding: EdgeInsets.zero,
                      autoFocus: false,
                      expands: true,
                      scrollable: true,
                      customStyles: DefaultStyles(
                        paragraph: DefaultTextBlockStyle(
                          body,
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(6, 10),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        placeHolder: DefaultTextBlockStyle(
                          body.copyWith(color: AppColors.textMuted),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        h2: DefaultTextBlockStyle(
                          AppTypography.newsHeadline().copyWith(
                            fontSize: 22,
                            height: 1.2,
                            color: AppColors.burgundyDark,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(8, 8),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        bold: body.copyWith(fontWeight: FontWeight.w700),
                        italic: body.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({
    required this.titleOn,
    required this.boldOn,
    required this.italicOn,
    required this.onTitle,
    required this.onBold,
    required this.onItalic,
  });

  final bool titleOn;
  final bool boldOn;
  final bool italicOn;
  final VoidCallback onTitle;
  final VoidCallback onBold;
  final VoidCallback onItalic;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Chip(
          label: 'Título',
          icon: Icons.title_rounded,
          selected: titleOn,
          onTap: onTitle,
        ),
        _Chip(
          label: 'Negrita',
          icon: Icons.format_bold_rounded,
          selected: boldOn,
          onTap: onBold,
        ),
        _Chip(
          label: 'Cursiva',
          icon: Icons.format_italic_rounded,
          selected: italicOn,
          onTap: onItalic,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.goldPale : AppColors.backgroundElevated,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? AppColors.gold
              : AppColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.burgundy),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.labelSmall(color: AppColors.burgundy)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
