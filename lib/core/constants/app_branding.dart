/// Nombre y textos visibles en la app (el paquete interno sigue siendo `cofradeo`).
abstract final class AppBranding {
  static const name = 'Círculo Cofrade';
  static const nameUpper = 'CÍRCULO COFRADE';
  static const tagline = 'Fe • Tradición • Hermandad';
  static const pitch =
      'La red seria de hermandades y cofrades. Comparte, sigue y vive la Semana Santa.';
  static const forumsPitch = 'Participa en la comunidad cofrade.';
  static const defaultBio = 'Miembro de Círculo Cofrade.';
  static const logoutConfirm = '¿Seguro que quieres salir de Círculo Cofrade?';
  static const joinCta = 'Únete a Círculo Cofrade';

  /// Origen https para enlaces compartidos y App Links.
  /// Requiere `assetlinks.json` / AASA en el dominio para abrir la app sola.
  static const webOrigin = 'https://cofradeo.app';
}
