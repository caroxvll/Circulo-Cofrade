/// Medianoche local. Para ti y el directo de Semana Santa cambian de jornada aquí.
DateTime startOfLocalDay([DateTime? now]) {
  final clock = now ?? DateTime.now();
  return DateTime(clock.year, clock.month, clock.day);
}

/// Tope del hilo dentro de una cita. Lo que no cabe sigue en la base.
const liveJornadaCap = 240;

/// Avisos de hoy y el tema que se mueve. Las de Círculo Cofrade no entran aquí:
/// se acumulan en el hilo.
const paraTiRiverLimit = 12;
