/// Convierte saltos de línea escapados (`\n`) del almacenamiento a saltos reales.
String normalizeStoredText(String raw) {
  if (!raw.contains(r'\n')) return raw;
  return raw.replaceAll(r'\n', '\n');
}
