import '../models/ss_live_update.dart';

final _mockSsLiveUpdates = <SsLiveUpdate>[
  SsLiveUpdate(
    id: 'mock-ss-1c',
    userId: 'mock-user-1c',
    authorHandle: '@triana_paso',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'La Esperanza de Triana',
    message: 'Ya en Pureza. Ambiente de barrio.',
    placeLabel: 'Calle Pureza',
    latitude: 37.3835,
    longitude: -6.0024,
    createdAt: DateTime.now().subtract(const Duration(minutes: 22)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-1b',
    userId: 'mock-user-1b',
    authorHandle: '@altozano_view',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'La Esperanza de Triana',
    message: 'Saliendo hacia el puente.',
    placeLabel: 'Altozano',
    latitude: 37.3850,
    longitude: -6.0010,
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-1',
    userId: 'mock-user-1',
    authorHandle: '@costalero_triana',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'La Esperanza de Triana',
    message: 'Ya cruzando el puente. Ritmo bueno, sin agobios.',
    placeLabel: 'Puente de Triana',
    latitude: 37.3862,
    longitude: -5.9998,
    createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-4c',
    userId: 'mock-user-4c',
    authorHandle: '@granpoder_early',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'Jesús del Gran Poder',
    message: 'Salida consolidada desde San Lorenzo.',
    placeLabel: 'Plaza de San Lorenzo',
    latitude: 37.3992,
    longitude: -5.9969,
    createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-4b',
    userId: 'mock-user-4b',
    authorHandle: '@granpoder_mid',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'Jesús del Gran Poder',
    message: 'Subiendo hacia Campana.',
    placeLabel: 'Calle Jesús del Gran Poder',
    latitude: 37.3960,
    longitude: -5.9955,
    createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-4',
    userId: 'mock-user-4',
    authorHandle: '@granpoder_sl',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'Jesús del Gran Poder',
    message: 'Entrando en carrera oficial. Paso muy asentado.',
    placeLabel: 'La Campana',
    latitude: 37.3928,
    longitude: -5.9945,
    createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-10b',
    userId: 'mock-user-10b',
    authorHandle: '@santa_marta_b',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'Santa Marta',
    message: 'Cerca de Plaza Nueva.',
    placeLabel: 'Plaza Nueva',
    latitude: 37.3880,
    longitude: -5.9955,
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-10',
    userId: 'mock-user-10',
    authorHandle: '@santa_marta',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'Santa Marta',
    message: 'Ya en el entorno de la Catedral. Público contenido.',
    placeLabel: 'Avenida de la Constitución',
    latitude: 37.3858,
    longitude: -5.9931,
    createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-2',
    userId: 'mock-user-2',
    authorHandle: '@plaza_nueva',
    kind: SsLiveUpdateKind.retraso,
    hermandadLabel: 'El Silencio',
    message: 'Retraso de unos 20 minutos a la altura de Campana.',
    placeLabel: 'Calle Sierpes / Campana',
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-5',
    userId: 'mock-user-5',
    authorHandle: '@expiracion_tr',
    kind: SsLiveUpdateKind.incidente,
    hermandadLabel: 'Cristo de la Expiración',
    message: 'Parón breve por viento lateral en el puente. Siguen.',
    placeLabel: 'Puente de Triana',
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-3',
    userId: 'mock-user-3',
    authorHandle: '@macarena_norte',
    kind: SsLiveUpdateKind.curiosidad,
    hermandadLabel: 'La Macarena',
    message: 'Aplauso cerrado en la puerta de la Basílica. Ambiente brutal.',
    placeLabel: 'Basílica de la Macarena',
    createdAt: DateTime.now().subtract(const Duration(minutes: 28)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-11',
    userId: 'mock-user-2b',
    authorHandle: '@francos_ok',
    kind: SsLiveUpdateKind.retraso,
    hermandadLabel: 'El Silencio',
    message: 'CONFIRMO sigue con 20–25 min. No es rumor.',
    placeLabel: 'Francos / Placentines',
    createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
  ),
  SsLiveUpdate(
    id: 'mock-ss-12',
    userId: 'mock-user-11',
    authorHandle: '@negritos_barrio',
    kind: SsLiveUpdateKind.posicion,
    hermandadLabel: 'Los Negritos',
    message: 'Ambiente de barrio, paso firme.',
    placeLabel: 'San Bartolomé',
    latitude: 37.3881,
    longitude: -5.9869,
    createdAt: DateTime.now().subtract(const Duration(minutes: 14)),
  ),
];

List<SsLiveUpdate> mockSsLiveUpdates({SsLiveUpdateKind? kind}) {
  final list = kind == null
      ? List<SsLiveUpdate>.from(_mockSsLiveUpdates)
      : _mockSsLiveUpdates.where((u) => u.kind == kind).toList();
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}

SsLiveUpdate addMockSsLiveUpdate({
  required String userId,
  required String authorHandle,
  required SsLiveUpdateKind kind,
  required String message,
  String? hermandadLabel,
  String? placeLabel,
  double? latitude,
  double? longitude,
}) {
  final hermandad = hermandadLabel?.trim();
  final place = placeLabel?.trim();
  final update = SsLiveUpdate(
    id: 'mock-ss-${_mockSsLiveUpdates.length + 1}',
    userId: userId,
    authorHandle: authorHandle,
    kind: kind,
    message: message.trim(),
    hermandadLabel: hermandad == null || hermandad.isEmpty ? null : hermandad,
    placeLabel: place == null || place.isEmpty ? null : place,
    latitude: latitude,
    longitude: longitude,
    createdAt: DateTime.now(),
  );
  _mockSsLiveUpdates.insert(0, update);
  return update;
}

DateTime? mockSsLastPostAt(String userId) {
  for (final update in _mockSsLiveUpdates) {
    if (update.userId == userId) return update.createdAt;
  }
  return null;
}
