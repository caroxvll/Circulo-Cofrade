import '../../shared/models/calendar_event.dart';

abstract final class AppAssets {
  /// Logo compacto (C morada + torre, sin texto) para la app.
  static const logo = 'assets/images/logo.png';

  /// Logo completo con texto; solo pantalla de login.
  static const logoLogin = 'assets/images/logo-login.png';
  static const loginBackground = 'assets/images/fondo.jpeg';
  static const googleLogo = 'assets/images/google.svg';
  static const logoIcon = 'assets/images/logo_icon.png';
  static const forumsBeigeBackground = 'assets/images/fondobeige.jpeg';
  static const countdownBanner = 'assets/images/banner_cuentaatras.jpg';

  /// Hero del listado de foros.
  static const heroProcesion = 'assets/images/hero_procesion.png';

  /// Fondo editorial del card de Noticias (nazarenos / Semana Santa).
  static const noticiasCover = 'assets/images/fondo_noticias.png';

  static const splashLogo = 'assets/images/logo.png';
  static const quizLiveLogo = 'assets/images/logopreguntavivo.png';
  static const adCostalesLaTrasera = 'assets/anuncio/clatrasera.png';
  static const sponsorDarte = 'assets/anuncio/darte.png';
  /// Medallones fijos de foro (JPG empaquetados en la app).
  static const forumCofradieroIcon = 'assets/icons/foro_cofradiero.jpg';
  static const forumHermandadesIcon = 'assets/icons/hermandades.jpg';
  static const forumMartilloIcon = 'assets/icons/martillo_trabajadera.jpg';
  static const forumPentagramaIcon = 'assets/icons/pentagrama_cofrade.jpg';
  static const forumNoticiasIcon = 'assets/icons/icono_noticias.png';

  /// Portadas de foros (ruta exacta en assets/images/forums/).
  static const forumCofradieroCover = 'assets/images/forums/foro-cofradiero.jpg';
  static const forumPentagramaCover = 'assets/images/forums/pentagrama_cofrade.jpeg';
  static const forumMartilloCover = 'assets/images/forums/martillo-trabajadera.JPG';
  static const forumHermandadesCover = 'assets/images/forums/hermandades.JPG';

  /// Portadas de temas destacados (añade los JPG/PNG en assets/icons/).
  static const topicCuaresmaIcon = 'assets/icons/cuaresma.JPG';
  static const topicSemanaSantaIcon = 'assets/icons/semana_santa.JPG';
  static const topicGloriasIcon = 'assets/icons/glorias.JPG';

  /// Iconos personalizados por tipo de evento (PNG o SVG).
  /// Colócalos en assets/icons/ con estos nombres exactos.
  static const _eventIcons = {
    EventType.procesion: 'assets/icons/procesion.png',
    EventType.gloria: 'assets/icons/gloria.png',
    EventType.ensayo: 'assets/icons/ensayo.png',
    EventType.iguala: 'assets/icons/iguala.svg',
    EventType.concierto: 'assets/icons/concierto.png',
    EventType.evento: 'assets/icons/evento.png',
  };

  static String eventIconPath(EventType type) => _eventIcons[type]!;
}
