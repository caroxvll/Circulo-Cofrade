/// Convierte saltos de línea escapados (`\n`) del almacenamiento a saltos reales
/// y quita escapes Markdown que Quill/DeltaToMarkdown deja visibles (`Cas\.` → `Cas.`).
String normalizeStoredText(String raw) {
  if (raw.isEmpty) return raw;

  var text = raw;
  if (text.contains(r'\n')) {
    text = text.replaceAll(r'\n', '\n');
  }
  return unescapeForumMarkdownLiterals(text);
}

/// Quita barras de escape Markdown innecesarias sin tocar `\n` ya normalizado.
String unescapeForumMarkdownLiterals(String raw) {
  if (!raw.contains(r'\')) return raw;
  // Caracteres que DeltaToMarkdown suele escapar y que en lectura se ven literales.
  return raw.replaceAllMapped(
    RegExp(r'\\([\\`*_{}\[\]()#+.!|?\-])'),
    (match) => match.group(1) ?? '',
  );
}
