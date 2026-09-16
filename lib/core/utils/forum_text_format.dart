import 'package:flutter/material.dart';

import 'forum_quill_markdown.dart';

/// URLs http(s) o www.
final RegExp urlInTextPattern = RegExp(
  r'(?:https?://[^\s<>\[\]()]+|www\.[^\s<>\[\]()]+)',
  caseSensitive: false,
);

final RegExp _boldInTextPattern = RegExp(r'\*\*(.+?)\*\*');

final RegExp _italicInTextPattern = RegExp(r'_(.+?)_');

/// Texto plano para extractos / búsqueda (sin marcadores).
String plainTextForExcerpt(String raw, {int maxLength = 160}) {
  var text = raw.trim();
  if (text.isEmpty) return '';

  // Mismo markdown que guarda el editor Quill → texto plano fiable.
  try {
    text = forumMarkdownToDocument(text).toPlainText();
    // Quill puede dejar ** o _ literales si no parseó el énfasis.
    text = _stripInlineMarkdown(text);
  } catch (_) {
    text = _stripMarkdownForExcerpt(raw);
  }

  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 1)}…';
}

/// Quita énfasis/enlaces en texto ya plano (sin bloques ```).
String _stripInlineMarkdown(String text) {
  var t = text;
  t = _replaceFirstGroup(markdownLinkPattern, t);
  t = _replaceFirstGroup(_boldInTextPattern, t);
  t = _replaceFirstGroup(_italicInTextPattern, t);
  return t;
}

String _replaceFirstGroup(RegExp pattern, String input) {
  return input.replaceAllMapped(
    pattern,
    (match) => match.group(1) ?? '',
  );
}

/// Respaldo si falla la conversión Quill (sin tocar bloques ``` con regex de énfasis).
String _stripMarkdownForExcerpt(String raw) {
  var text = raw;
  text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  text = text.replaceAll(RegExp(r'`[^`\n]+`'), ' ');
  text = _stripInlineMarkdown(text);
  text = text.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
  return text;
}

void applyItalicFormatting(TextEditingController controller) {
  final selection = controller.selection;
  if (!selection.isValid) return;

  final text = controller.text;
  if (selection.isCollapsed) {
    final pos = selection.baseOffset;
    const insert = '__';
    final newText = '${text.substring(0, pos)}$insert${text.substring(pos)}';
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + 1),
    );
    return;
  }

  final selected = text.substring(selection.start, selection.end);
  final wrapped = '_${selected}_';
  final newText = text.replaceRange(selection.start, selection.end, wrapped);
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: selection.start + wrapped.length,
    ),
  );
}

void applyBoldFormatting(TextEditingController controller) {
  final selection = controller.selection;
  if (!selection.isValid) return;

  final text = controller.text;
  if (selection.isCollapsed) {
    final pos = selection.baseOffset;
    final newText = '${text.substring(0, pos)}****${text.substring(pos)}';
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + 2),
    );
    return;
  }

  final selected = text.substring(selection.start, selection.end);
  final wrapped = '**$selected**';
  final newText =
      text.replaceRange(selection.start, selection.end, wrapped);
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: selection.start + wrapped.length,
    ),
  );
}

void insertParagraphBreak(TextEditingController controller) {
  final selection = controller.selection;
  if (!selection.isValid) return;
  final text = controller.text;
  final pos = selection.baseOffset;
  const insert = '\n\n';
  final newText = '${text.substring(0, pos)}$insert${text.substring(pos)}';
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: pos + insert.length),
  );
}

void insertLinkAtSelection(
  TextEditingController controller, {
  required String url,
  String? label,
}) {
  final selection = controller.selection;
  if (!selection.isValid) return;

  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) return;

  final display = (label?.trim().isNotEmpty == true)
      ? label!.trim()
      : trimmedUrl;
  final token = '[$display]($trimmedUrl)';

  final text = controller.text;
  if (selection.isCollapsed) {
    final pos = selection.baseOffset;
    final spacer = pos > 0 && text[pos - 1] != ' ' ? ' ' : '';
    final suffix = pos < text.length && text[pos] != ' ' ? ' ' : '';
    final insert = '$spacer$token$suffix';
    final newText = '${text.substring(0, pos)}$insert${text.substring(pos)}';
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + insert.length),
    );
    return;
  }

  final newText =
      text.replaceRange(selection.start, selection.end, token);
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: selection.start + token.length,
    ),
  );
}

/// Enlaces markdown [texto](url) además de URLs sueltas.
final RegExp markdownLinkPattern = RegExp(
  r'\[([^\]]+)\]\(([^)]+)\)',
);

String normalizeUrlForLaunch(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}
