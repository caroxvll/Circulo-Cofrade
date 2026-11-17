/// Ruta interna de la app. Rechaza URLs absolutas y esquemas ajenos.
bool isSafeInternalLocation(String? value) {
  if (value == null || value.isEmpty) return false;
  if (!value.startsWith('/')) return false;
  if (value.startsWith('//')) return false;
  if (value.contains('://')) return false;
  if (value.contains('\\')) return false;
  return true;
}

String? safeInternalLocation(String? value) =>
    isSafeInternalLocation(value) ? value : null;
