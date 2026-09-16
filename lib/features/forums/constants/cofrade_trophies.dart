/// Trofeos del foro: cada uno se desbloquea **una vez** y suma puntos fijos.
///
/// Los puntos totales determinan el [CofradeRank] visible bajo el @handle.
abstract final class CofradeTrophies {
  static const minValidReplyLength = 20;

  static const all = <CofradeTrophy>[
    // ── Participación ─────────────────────────────────────────────────────
    CofradeTrophy(
      id: 'first_reply',
      title: 'Cofrade de a pie',
      description: 'Publica tu primer mensaje en el foro.',
      points: 1,
      category: CofradeTrophyCategory.participation,
      rule: CofradeTrophyRule.minValidReplies(1),
    ),
    CofradeTrophy(
      id: 'replies_10',
      title: 'Voz en el foro',
      description: 'Publica 10 mensajes con contenido.',
      points: 2,
      category: CofradeTrophyCategory.participation,
      rule: CofradeTrophyRule.minValidReplies(10),
    ),
    CofradeTrophy(
      id: 'replies_30',
      title: 'Habitual del tablón',
      description: 'Publica 30 mensajes con contenido.',
      points: 3,
      category: CofradeTrophyCategory.participation,
      rule: CofradeTrophyRule.minValidReplies(30),
    ),
    CofradeTrophy(
      id: 'replies_100',
      title: 'Veterano del hilo',
      description: 'Publica 100 mensajes con contenido.',
      points: 5,
      category: CofradeTrophyCategory.participation,
      rule: CofradeTrophyRule.minValidReplies(100),
    ),

    // ── Temas ─────────────────────────────────────────────────────────────
    CofradeTrophy(
      id: 'first_topic',
      title: 'Primer tema',
      description: 'Abre tu primer hilo en el foro.',
      points: 3,
      category: CofradeTrophyCategory.topics,
      rule: CofradeTrophyRule.minTopicsCreated(1),
    ),
    CofradeTrophy(
      id: 'topics_5',
      title: 'Iniciador',
      description: 'Abre 5 temas en el foro.',
      points: 4,
      category: CofradeTrophyCategory.topics,
      rule: CofradeTrophyRule.minTopicsCreated(5),
    ),
    CofradeTrophy(
      id: 'topics_15',
      title: 'Debate cofrade',
      description: 'Abre 15 temas en el foro.',
      points: 8,
      category: CofradeTrophyCategory.topics,
      rule: CofradeTrophyRule.minTopicsCreated(15),
    ),
    CofradeTrophy(
      id: 'topics_40',
      title: 'Tablón activo',
      description: 'Abre 40 temas en el foro.',
      points: 12,
      category: CofradeTrophyCategory.topics,
      rule: CofradeTrophyRule.minTopicsCreated(40),
    ),

    // ── Visitas (suma en tus temas publicados) ────────────────────────────
    CofradeTrophy(
      id: 'topic_views_100',
      title: 'Miradas al paso',
      description: 'Tus temas suman 100 visitas.',
      points: 2,
      category: CofradeTrophyCategory.views,
      rule: CofradeTrophyRule.minTopicViews(100),
    ),
    CofradeTrophy(
      id: 'topic_views_500',
      title: 'Trending local',
      description: 'Tus temas suman 500 visitas.',
      points: 5,
      category: CofradeTrophyCategory.views,
      rule: CofradeTrophyRule.minTopicViews(500),
    ),
    CofradeTrophy(
      id: 'topic_views_2000',
      title: 'Hilo popular',
      description: 'Tus temas suman 2.000 visitas.',
      points: 10,
      category: CofradeTrophyCategory.views,
      rule: CofradeTrophyRule.minTopicViews(2000),
    ),
    CofradeTrophy(
      id: 'topic_views_10000',
      title: 'Hit del foro',
      description: 'Tus temas suman 10.000 visitas.',
      points: 15,
      category: CofradeTrophyCategory.views,
      rule: CofradeTrophyRule.minTopicViews(10000),
    ),

    // ── Reacciones recibidas ──────────────────────────────────────────────
    CofradeTrophy(
      id: 'reactions_1',
      title: 'Primer aplauso',
      description: 'Recibe tu primera reacción en el foro.',
      points: 2,
      category: CofradeTrophyCategory.reactions,
      rule: CofradeTrophyRule.minReactionsReceived(1),
    ),
    CofradeTrophy(
      id: 'reactions_25',
      title: 'Querido en el foro',
      description: 'Recibe 25 reacciones en tus mensajes.',
      points: 5,
      category: CofradeTrophyCategory.reactions,
      rule: CofradeTrophyRule.minReactionsReceived(25),
    ),
    CofradeTrophy(
      id: 'reactions_100',
      title: 'Muy valorado',
      description: 'Recibe 100 reacciones en tus mensajes.',
      points: 10,
      category: CofradeTrophyCategory.reactions,
      rule: CofradeTrophyRule.minReactionsReceived(100),
    ),
    CofradeTrophy(
      id: 'reactions_250',
      title: 'Referente',
      description: 'Recibe 250 reacciones en tus mensajes.',
      points: 15,
      category: CofradeTrophyCategory.reactions,
      rule: CofradeTrophyRule.minReactionsReceived(250),
    ),
    CofradeTrophy(
      id: 'reactions_500',
      title: 'Voz respetada',
      description: 'Recibe 500 reacciones en tus mensajes.',
      points: 20,
      category: CofradeTrophyCategory.reactions,
      rule: CofradeTrophyRule.minReactionsReceived(500),
    ),

    // ── Seguidores de perfil ──────────────────────────────────────────────
    CofradeTrophy(
      id: 'followers_5',
      title: 'Conocido',
      description: 'Consigue 5 seguidores en tu perfil.',
      points: 3,
      category: CofradeTrophyCategory.followers,
      rule: CofradeTrophyRule.minFollowers(5),
    ),
    CofradeTrophy(
      id: 'followers_25',
      title: 'Seguido',
      description: 'Consigue 25 seguidores en tu perfil.',
      points: 8,
      category: CofradeTrophyCategory.followers,
      rule: CofradeTrophyRule.minFollowers(25),
    ),
    CofradeTrophy(
      id: 'followers_100',
      title: 'Referencia',
      description: 'Consigue 100 seguidores en tu perfil.',
      points: 15,
      category: CofradeTrophyCategory.followers,
      rule: CofradeTrophyRule.minFollowers(100),
    ),

    // ── Hashtags ──────────────────────────────────────────────────────────
    CofradeTrophy(
      id: 'hashtag_followers_5',
      title: 'Etiqueta pionera',
      description:
          'Un hashtag que popularizaste alcanza 5 seguidores.',
      points: 4,
      category: CofradeTrophyCategory.hashtags,
      rule: CofradeTrophyRule.minHashtagFollowers(5),
    ),
    CofradeTrophy(
      id: 'hashtag_followers_25',
      title: 'Hashtag vivo',
      description:
          'Un hashtag que popularizaste alcanza 25 seguidores.',
      points: 10,
      category: CofradeTrophyCategory.hashtags,
      rule: CofradeTrophyRule.minHashtagFollowers(25),
    ),

    // ── Seguidores de temas ───────────────────────────────────────────────
    CofradeTrophy(
      id: 'topic_followers_10',
      title: 'Hilo seguido',
      description: 'Uno de tus temas consigue 10 seguidores.',
      points: 4,
      category: CofradeTrophyCategory.topics,
      rule: CofradeTrophyRule.minTopicFollowers(10),
    ),
    CofradeTrophy(
      id: 'topic_followers_50',
      title: 'Debate en marcha',
      description: 'Uno de tus temas consigue 50 seguidores.',
      points: 8,
      category: CofradeTrophyCategory.topics,
      rule: CofradeTrophyRule.minTopicFollowers(50),
    ),
  ];

  static const maxPoints = 166;

  static CofradeTrophy? byId(String id) {
    for (final trophy in all) {
      if (trophy.id == id) return trophy;
    }
    return null;
  }
}

enum CofradeTrophyCategory {
  participation('Participación'),
  topics('Temas'),
  views('Visitas'),
  reactions('Reacciones'),
  followers('Seguidores'),
  hashtags('Hashtags');

  const CofradeTrophyCategory(this.label);

  final String label;
}

enum CofradeTrophyRuleKind {
  validReplies,
  topicsCreated,
  topicViews,
  reactionsReceived,
  followers,
  hashtagFollowers,
  topicFollowers,
}

final class CofradeTrophyRule {
  const CofradeTrophyRule._(this.kind, this.threshold);

  const CofradeTrophyRule.minValidReplies(int count)
      : this._(CofradeTrophyRuleKind.validReplies, count);

  const CofradeTrophyRule.minTopicsCreated(int count)
      : this._(CofradeTrophyRuleKind.topicsCreated, count);

  const CofradeTrophyRule.minTopicViews(int count)
      : this._(CofradeTrophyRuleKind.topicViews, count);

  const CofradeTrophyRule.minReactionsReceived(int count)
      : this._(CofradeTrophyRuleKind.reactionsReceived, count);

  const CofradeTrophyRule.minFollowers(int count)
      : this._(CofradeTrophyRuleKind.followers, count);

  const CofradeTrophyRule.minHashtagFollowers(int count)
      : this._(CofradeTrophyRuleKind.hashtagFollowers, count);

  const CofradeTrophyRule.minTopicFollowers(int count)
      : this._(CofradeTrophyRuleKind.topicFollowers, count);

  final CofradeTrophyRuleKind kind;
  final int threshold;
}

final class CofradeTrophy {
  const CofradeTrophy({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.category,
    required this.rule,
  });

  final String id;
  final String title;
  final String description;
  final int points;
  final CofradeTrophyCategory category;
  final CofradeTrophyRule rule;
}

/// Métricas del foro usadas para evaluar trofeos.
final class CofradeForumStats {
  const CofradeForumStats({
    this.validReplyCount = 0,
    this.topicsCreatedCount = 0,
    this.topicViewsTotal = 0,
    this.reactionsReceived = 0,
    this.followerCount = 0,
    this.maxHashtagFollowers = 0,
    this.maxTopicFollowers = 0,
  });

  final int validReplyCount;
  final int topicsCreatedCount;
  final int topicViewsTotal;
  final int reactionsReceived;
  final int followerCount;

  /// Mayor número de seguidores entre hashtags que el usuario popularizó.
  final int maxHashtagFollowers;

  /// Mayor número de seguidores entre los temas abiertos por el usuario.
  final int maxTopicFollowers;

  int statFor(CofradeTrophyRuleKind kind) => switch (kind) {
        CofradeTrophyRuleKind.validReplies => validReplyCount,
        CofradeTrophyRuleKind.topicsCreated => topicsCreatedCount,
        CofradeTrophyRuleKind.topicViews => topicViewsTotal,
        CofradeTrophyRuleKind.reactionsReceived => reactionsReceived,
        CofradeTrophyRuleKind.followers => followerCount,
        CofradeTrophyRuleKind.hashtagFollowers => maxHashtagFollowers,
        CofradeTrophyRuleKind.topicFollowers => maxTopicFollowers,
      };

  bool meets(CofradeTrophyRule rule) => statFor(rule.kind) >= rule.threshold;
}
