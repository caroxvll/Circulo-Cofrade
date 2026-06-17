final RegExp mentionInTextPattern = RegExp(r'@([a-zA-Z0-9_]+)');

/// Fragmento @handle activo bajo el cursor (estilo Instagram).
class ActiveMention {
  const ActiveMention({
    required this.startIndex,
    required this.query,
  });

  final int startIndex;
  final String query;
}

ActiveMention? parseActiveMention(String text, int cursorOffset) {
  if (cursorOffset < 0 || cursorOffset > text.length) return null;

  final beforeCursor = text.substring(0, cursorOffset);
  final match = RegExp(r'@([a-zA-Z0-9_]*)$').firstMatch(beforeCursor);
  if (match == null) return null;

  return ActiveMention(
    startIndex: match.start,
    query: match.group(1) ?? '',
  );
}

String applyMentionSelection({
  required String text,
  required int cursorOffset,
  required int mentionStartIndex,
  required String handle,
}) {
  final normalized = handle.replaceAll('@', '');
  final before = text.substring(0, mentionStartIndex);
  final after = text.substring(cursorOffset);
  return '$before@$normalized $after';
}

int cursorAfterMention(int mentionStartIndex, String handle) {
  final normalized = handle.replaceAll('@', '');
  return mentionStartIndex + normalized.length + 2;
}
