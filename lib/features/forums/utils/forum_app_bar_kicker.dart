/// Subtítulo corto del header editorial de cada foro (estilo Noticias).
String forumTopicAppBarKicker(String forumId) => switch (forumId) {
      'noticias' => 'ACTUALIDAD COFRADE',
      'foro-cofradiero' => 'TERTULIA COFRADE',
      'pentagrama-cofrade' => 'MÚSICA COFRADE',
      'martillo-trabajadera' => 'CAPATACES Y COSTAL',
      'hermandades' => 'CANAL OFICIAL',
      'semana-santa' => 'SEMANA MAYOR',
      'cuaresma' => 'CAMINO A LA SEMANA MAYOR',
      'glorias' => 'GLORIAS SEVILLANAS',
      _ => 'FORO COFRADE',
    };
