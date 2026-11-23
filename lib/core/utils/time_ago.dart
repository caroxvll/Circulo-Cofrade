const _esMonthsShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sept',
  'oct',
  'nov',
  'dic',
];

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

/// Reloj local `HH:mm`.
String formatClockTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hours = local.hour.toString().padLeft(2, '0');
  final minutes = local.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

/// Sello de un directo: la hora de reloj, no «hace 22 horas».
///
/// Mismo día → `17:24`. Ayer → `ayer 19:10`. Antes → `22 nov · 19:10`.
String formatLiveStamp(DateTime dateTime, {DateTime? now}) {
  final local = dateTime.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final clock = formatClockTime(local);
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(day).inDays;

  if (diffDays <= 0) return clock;
  if (diffDays == 1) return 'ayer $clock';

  final month = _esMonthsShort[local.month - 1];
  if (local.year != reference.year) {
    return '${local.day} $month ${local.year} · $clock';
  }
  return '${local.day} $month · $clock';
}
