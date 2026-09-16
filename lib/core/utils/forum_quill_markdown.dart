import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

import 'text_normalize.dart';

final _mdToDelta = MarkdownToDelta(
  markdownDocument: md.Document(),
);
final _deltaToMd = DeltaToMarkdown();

Document forumMarkdownToDocument(String markdown) {
  if (markdown.trim().isEmpty) {
    return Document();
  }
  try {
    return Document.fromDelta(_mdToDelta.convert(markdown));
  } catch (_) {
    return Document()..insert(0, markdown);
  }
}

String forumDocumentToMarkdown(Document document) {
  try {
    return unescapeForumMarkdownLiterals(
      _deltaToMd.convert(document.toDelta()).trim(),
    );
  } catch (_) {
    return document.toPlainText().trim();
  }
}
