String formatTimeAgo(DateTime dateTime, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(dateTime.toLocal());

  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? 'hace 1 hora' : 'hace ${diff.inHours} horas';
  }
  if (diff.inDays < 7) {
    return diff.inDays == 1 ? 'hace 1 día' : 'hace ${diff.inDays} días';
  }
  if (diff.inDays < 30) {
    final weeks = (diff.inDays / 7).floor();
    return weeks == 1 ? 'hace 1 semana' : 'hace $weeks semanas';
  }
  return 'hace ${(diff.inDays / 30).floor()} meses';
}
