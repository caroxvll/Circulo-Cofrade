/// Cómo va la red ahora mismo.
///
/// En una bulla el móvil a menudo “tiene datos” y no carga: [degraded].
/// Hacia fuera solo hay un aviso: sin conexión.
enum AppNetworkKind {
  online,
  degraded,
  offline,
}

class AppNetworkStatus {
  const AppNetworkStatus({
    this.kind = AppNetworkKind.online,
    this.lastOnlineAt,
  });

  final AppNetworkKind kind;
  final DateTime? lastOnlineAt;

  bool get isOnline => kind == AppNetworkKind.online;
  bool get isDegraded => kind == AppNetworkKind.degraded;
  bool get isOffline => kind == AppNetworkKind.offline;

  /// Un solo aviso, y solo cuando ya está claro que no llega nada.
  bool get showBanner => isOffline || isDegraded;

  String get bannerMessage =>
      'Sin conexión · se muestra lo último que se pudo cargar';

  String get liveSendBlockedMessage =>
      'Sin conexión. En cuanto vuelva, envíalo otra vez.';
}
