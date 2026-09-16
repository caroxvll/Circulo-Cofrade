/// Bloques estructurados de Markdown generados por el editor Quill.
enum ForumMarkdownBlockKind { paragraph, bulletList, orderedList, blockquote }

class ForumMarkdownBlock {
  const ForumMarkdownBlock._(this.kind, this.lines);

  ForumMarkdownBlock.paragraph(String text)
      : this._(ForumMarkdownBlockKind.paragraph, [text]);

  ForumMarkdownBlock.bulletList(List<String> items)
      : this._(ForumMarkdownBlockKind.bulletList, items);

  ForumMarkdownBlock.orderedList(List<String> items)
      : this._(ForumMarkdownBlockKind.orderedList, items);

  ForumMarkdownBlock.blockquote(List<String> lines)
      : this._(ForumMarkdownBlockKind.blockquote, lines);

  final ForumMarkdownBlockKind kind;
  final List<String> lines;
}

final _bulletLine = RegExp(r'^(\s*)([-*+])\s+(.*)$');
final _orderedLine = RegExp(r'^\s*(\d+)\.\s+(.*)$');
final _quoteLine = RegExp(r'^>\s?(.*)$');

bool _isStructuredLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  return _bulletLine.hasMatch(line) ||
      _orderedLine.hasMatch(line) ||
      _quoteLine.hasMatch(line);
}

/// Divide el Markdown en párrafos, listas y citas para lectura editorial.
List<ForumMarkdownBlock> parseForumMarkdownBlocks(String raw) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return const [];

  final lines = text.split('\n');
  final blocks = <ForumMarkdownBlock>[];
  var index = 0;

  while (index < lines.length) {
    final line = lines[index];
    if (line.trim().isEmpty) {
      index++;
      continue;
    }

    final bullet = _bulletLine.firstMatch(line);
    if (bullet != null) {
      final items = <String>[];
      while (index < lines.length) {
        final match = _bulletLine.firstMatch(lines[index]);
        if (match == null) break;
        items.add(match.group(3)!.trim());
        index++;
      }
      if (items.isNotEmpty) {
        blocks.add(ForumMarkdownBlock.bulletList(items));
      }
      continue;
    }

    final ordered = _orderedLine.firstMatch(line);
    if (ordered != null) {
      final items = <String>[];
      while (index < lines.length) {
        final match = _orderedLine.firstMatch(lines[index]);
        if (match == null) break;
        items.add(match.group(2)!.trim());
        index++;
      }
      if (items.isNotEmpty) {
        blocks.add(ForumMarkdownBlock.orderedList(items));
      }
      continue;
    }

    final quote = _quoteLine.firstMatch(line);
    if (quote != null) {
      final quoteLines = <String>[];
      while (index < lines.length) {
        final match = _quoteLine.firstMatch(lines[index]);
        if (match == null) break;
        quoteLines.add(match.group(1)!.trim());
        index++;
      }
      if (quoteLines.isNotEmpty) {
        blocks.add(ForumMarkdownBlock.blockquote(quoteLines));
      }
      continue;
    }

    final paragraphLines = <String>[];
    while (index < lines.length) {
      final current = lines[index];
      if (current.trim().isEmpty || _isStructuredLine(current)) break;
      paragraphLines.add(current);
      index++;
    }
    if (paragraphLines.isNotEmpty) {
      blocks.add(ForumMarkdownBlock.paragraph(paragraphLines.join('\n').trim()));
    }
  }

  return blocks;
}

bool forumMarkdownHasStructure(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  for (final line in lines) {
    if (_isStructuredLine(line)) return true;
  }
  return false;
}
