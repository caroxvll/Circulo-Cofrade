final RegExp hashtagInTextPattern =
    RegExp(r'#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)');

class ActiveHashtag {
  const ActiveHashtag({
    required this.startIndex,
    required this.query,
  });

  final int startIndex;
  final String query;
}

ActiveHashtag? parseActiveHashtag(String text, int cursorOffset) {
  if (cursorOffset < 0 || cursorOffset > text.length) return null;

  final beforeCursor = text.substring(0, cursorOffset);
  final match = RegExp(r'#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]*)$').firstMatch(beforeCursor);
  if (match == null) return null;

  return ActiveHashtag(
    startIndex: match.start,
    query: match.group(1) ?? '',
  );
}

String applyHashtagSelection({
  required String text,
  required int cursorOffset,
  required int hashtagStartIndex,
  required String hashtag,
}) {
  final normalized = hashtag.startsWith('#') ? hashtag : '#$hashtag';
  final tag = normalized.replaceAll(' ', '');
  final before = text.substring(0, hashtagStartIndex);
  final after = text.substring(cursorOffset);
  return '$before$tag $after';
}

int cursorAfterHashtag(int hashtagStartIndex, String hashtag) {
  final normalized = hashtag.startsWith('#') ? hashtag : '#$hashtag';
  return hashtagStartIndex + normalized.length + 1;
}

List<String> filterHashtagSuggestions(String query, List<String> candidates) {
  final q = query.toLowerCase();
  if (q.isEmpty) {
    return candidates.take(6).toList();
  }
  return candidates
      .where((tag) {
        final bare = tag.replaceAll('#', '').toLowerCase();
        return bare.startsWith(q) || bare.contains(q);
      })
      .take(6)
      .toList();
}
