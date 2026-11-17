/// Medianoche local. Para ti y el directo de Semana Santa cambian de jornada aquí.
DateTime startOfLocalDay([DateTime? now]) {
  final clock = now ?? DateTime.now();
  return DateTime(clock.year, clock.month, clock.day);
}

/// Tope del hilo dentro de una cita. Lo que no cabe sigue en la base.
const liveJornadaCap = 240;

/// Piezas que caben en el río de Para ti, de más nuevo a más viejo.
const paraTiRiverLimit = 12;
