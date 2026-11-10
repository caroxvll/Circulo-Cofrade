/// El comunicado se guarda en un solo texto. La primera línea es el título.
({String title, String body}) splitOfficialPostDraft(String raw) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return (title: '', body: '');

  final breakAt = text.indexOf('\n');
  if (breakAt < 0) {
    if (text.length <= 90) return (title: plainOfficialTitle(text), body: '');
    return (title: '', body: text);
  }

  return (
    title: plainOfficialTitle(text.substring(0, breakAt)),
    body: text.substring(breakAt + 1).trim(),
  );
}

String joinOfficialPostContent({
  required String title,
  required String body,
}) {
  final headline = title.trim();
  final rest = body.trim();
  if (headline.isEmpty) return rest;
  if (rest.isEmpty) return headline;
  return '$headline\n\n$rest';
}

String plainOfficialTitle(String line) {
  var value = line.trim();
  value = value.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  value = value.replaceAllMapped(
    RegExp(r'_(.+?)_'),
    (match) => match.group(1) ?? '',
  );
  return value.trim();
}
