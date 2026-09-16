/// Escalera oficial de rangos cofrades (Semana Santa sevillana).
///
/// El rango visible se deriva de los [CofradeTrophies.points] acumulados.
abstract final class CofradeRanks {
  static const ladder = <CofradeRank>[
    CofradeRank(level: 1, title: 'Cofrade de a pie', minPoints: 0),
    CofradeRank(level: 2, title: 'Hermano', minPoints: 1),
    CofradeRank(level: 3, title: 'Nazareno', minPoints: 3),
    CofradeRank(level: 4, title: 'Nazareno 1.º Tramo', minPoints: 6),
    CofradeRank(level: 5, title: 'Nazareno 2.º Tramo', minPoints: 9),
    CofradeRank(level: 6, title: 'Nazareno 3.º Tramo', minPoints: 13),
    CofradeRank(level: 7, title: 'Nazareno 4.º Tramo', minPoints: 17),
    CofradeRank(level: 8, title: 'Nazareno 5.º Tramo', minPoints: 22),
    CofradeRank(level: 9, title: 'Nazareno Último Tramo', minPoints: 27),
    CofradeRank(level: 10, title: 'Costalero', minPoints: 33),
    CofradeRank(level: 11, title: 'Contraguía', minPoints: 40),
    CofradeRank(level: 12, title: 'Capataz', minPoints: 48),
    CofradeRank(level: 13, title: 'Diputado de Tramo', minPoints: 56),
    CofradeRank(level: 14, title: 'Diputado de Cultos', minPoints: 65),
    CofradeRank(level: 15, title: 'Diputado de Caridad', minPoints: 74),
    CofradeRank(level: 16, title: 'Diputado de Formación', minPoints: 84),
    CofradeRank(level: 17, title: 'Diputado de Juventud', minPoints: 94),
    CofradeRank(level: 18, title: 'Auxiliar de Priostía', minPoints: 104),
    CofradeRank(level: 19, title: 'Prioste II', minPoints: 114),
    CofradeRank(level: 20, title: 'Prioste I', minPoints: 124),
    CofradeRank(level: 21, title: 'Mayordomo II', minPoints: 132),
    CofradeRank(level: 22, title: 'Mayordomo I', minPoints: 138),
    CofradeRank(level: 23, title: 'Secretario', minPoints: 143),
    CofradeRank(level: 24, title: 'Fiscal', minPoints: 147),
    CofradeRank(
      level: 25,
      title: 'Diputado Mayor de Gobierno',
      minPoints: 152,
    ),
    CofradeRank(
      level: 26,
      title: 'Teniente de Hermano Mayor',
      minPoints: 158,
    ),
    CofradeRank(level: 27, title: 'Hermano Mayor', minPoints: 163),
  ];
}

final class CofradeRank {
  const CofradeRank({
    required this.level,
    required this.title,
    required this.minPoints,
  });

  final int level;
  final String title;
  final int minPoints;
}
