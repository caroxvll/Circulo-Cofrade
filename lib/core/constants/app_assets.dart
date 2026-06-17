import '../../shared/models/calendar_event.dart';

abstract final class AppAssets {
  /// Logo compacto (C morada + torre, sin texto) para la app.
  static const logo = 'assets/images/logo.png';
  /// Logo completo con texto; solo pantalla de login.
  static const logoLogin = 'assets/images/logo-login.png';
  static const logoIcon = 'assets/images/logo_icon.png';
  /// Hero del listado de foros (opcional: añade el JPG en assets/images/).
  static const heroProcesion = 'assets/images/hero_procesion.jpg';
  static const splashLogo = 'assets/images/logo.png';

  /// Iconos personalizados por tipo de evento (PNG o SVG).
  /// Colócalos en assets/icons/ con estos nombres exactos.
  static const _eventIcons = {
    EventType.procesion: 'assets/icons/procesion.png',
    EventType.gloria: 'assets/icons/gloria.png',
    EventType.ensayo: 'assets/icons/ensayo.png',
    EventType.iguala: 'assets/icons/iguala.png',
    EventType.concierto: 'assets/icons/concierto.png',
    EventType.evento: 'assets/icons/evento.png',
  };

  static String eventIconPath(EventType type) => _eventIcons[type]!;
}
