import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/theme/app_colors.dart';
import '../topic_detail_typography.dart';

enum ForumComposeToolbar { standard, editorial }

QuillEditorConfig forumQuillEditorConfig({
  required String? hintText,
  bool expands = false,
}) {
  final baseStyle = TopicDetailTypography.body();

  return QuillEditorConfig(
    placeholder: hintText ?? 'Escribe tu mensaje…',
    padding: EdgeInsets.zero,
    autoFocus: false,
    expands: expands,
    scrollable: true,
    customStyles: DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        baseStyle,
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(6, 12),
        const VerticalSpacing(0, 0),
        null,
      ),
      placeHolder: DefaultTextBlockStyle(
        baseStyle.copyWith(color: AppColors.textMuted),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
      h1: DefaultTextBlockStyle(
        TopicDetailTypography.title(),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(10, 8),
        const VerticalSpacing(0, 0),
        null,
      ),
      h2: DefaultTextBlockStyle(
        TopicDetailTypography.title().copyWith(fontSize: 15),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(8, 6),
        const VerticalSpacing(0, 0),
        null,
      ),
      h3: DefaultTextBlockStyle(
        baseStyle.copyWith(fontWeight: FontWeight.w700),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(6, 4),
        const VerticalSpacing(0, 0),
        null,
      ),
      lists: DefaultListBlockStyle(
        baseStyle,
        const HorizontalSpacing(16, 0),
        const VerticalSpacing(4, 8),
        const VerticalSpacing(0, 6),
        null,
        null,
      ),
      quote: DefaultTextBlockStyle(
        baseStyle.copyWith(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        const HorizontalSpacing(12, 0),
        const VerticalSpacing(8, 8),
        const VerticalSpacing(0, 0),
        BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.gold.withValues(alpha: 0.6),
              width: 3,
            ),
          ),
        ),
      ),
      link: baseStyle.copyWith(
        color: AppColors.burgundy,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.burgundy,
      ),
    ),
  );
}

QuillSimpleToolbarConfig forumQuillToolbarConfig(ForumComposeToolbar toolbar) {
  final editorial = toolbar == ForumComposeToolbar.editorial;

  return QuillSimpleToolbarConfig(
    showAlignmentButtons: false,
    showBackgroundColorButton: false,
    showCenterAlignment: false,
    showClearFormat: false,
    showColorButton: false,
    showDirection: false,
    showFontFamily: false,
    showFontSize: false,
    showHeaderStyle: false,
    showIndent: false,
    showInlineCode: false,
    showJustifyAlignment: false,
    showLeftAlignment: false,
    showLink: true,
    showListBullets: editorial,
    showListNumbers: editorial,
    showListCheck: false,
    showQuote: editorial,
    showRedo: false,
    showRightAlignment: false,
    showSearchButton: false,
    showSmallButton: false,
    showStrikeThrough: false,
    showSubscript: false,
    showSuperscript: false,
    showUnderLineButton: false,
    showUndo: true,
    multiRowsDisplay: editorial,
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base: QuillToolbarBaseButtonOptions(
        iconTheme: QuillIconTheme(
          iconButtonSelectedData: IconButtonData(
            style: IconButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              backgroundColor: AppColors.burgundy.withValues(alpha: 0.12),
            ),
          ),
          iconButtonUnselectedData: IconButtonData(
            style: IconButton.styleFrom(
              foregroundColor: AppColors.burgundy,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget forumQuillToolbar({
  required QuillController controller,
  ForumComposeToolbar toolbar = ForumComposeToolbar.standard,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
    ),
    child: QuillSimpleToolbar(
      controller: controller,
      config: forumQuillToolbarConfig(toolbar),
    ),
  );
}
