enum QuizQuestionStatus { draft, pendingReview, approved, rejected }

enum QuizRoundStatus { scheduled, live, closed }

enum QuizOption { a, b, c, d }

QuizOption? quizOptionFromString(String? value) {
  return switch (value) {
    'a' => QuizOption.a,
    'b' => QuizOption.b,
    'c' => QuizOption.c,
    'd' => QuizOption.d,
    _ => null,
  };
}

String quizOptionToString(QuizOption option) => option.name;

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    this.imageUrl,
    this.audioUrl,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.explanation,
    required this.status,
    this.createdBy,
    this.createdAt,
    this.rejectionReason,
  });

  final String id;
  final String prompt;
  final String? imageUrl;
  final String? audioUrl;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final QuizOption correctOption;
  final String? explanation;
  final QuizQuestionStatus status;
  final String? createdBy;
  final DateTime? createdAt;
  final String? rejectionReason;

  bool get hasAudio {
    final u = audioUrl?.trim();
    return u != null && u.isNotEmpty;
  }

  String labelFor(QuizOption option) => switch (option) {
        QuizOption.a => optionA,
        QuizOption.b => optionB,
        QuizOption.c => optionC,
        QuizOption.d => optionD,
      };
}

class QuizRound {
  const QuizRound({
    required this.id,
    required this.questionId,
    required this.status,
    this.launchedAt,
    this.closesAt,
    this.answerSeconds = 15,
  });

  final String id;
  final String questionId;
  final QuizRoundStatus status;
  final DateTime? launchedAt;
  final DateTime? closesAt;
  final int answerSeconds;
}

class QuizAnswerState {
  const QuizAnswerState({
    this.openedAt,
    this.answeredAt,
    this.selectedOption,
    this.isCorrect,
    this.score,
    this.correctOption,
    this.forfeited = false,
    this.timedOut = false,
  });

  final DateTime? openedAt;
  final DateTime? answeredAt;
  final QuizOption? selectedOption;
  final bool? isCorrect;
  final int? score;
  final QuizOption? correctOption;
  final bool forfeited;
  final bool timedOut;

  bool get hasAnswered => answeredAt != null;

  /// Contestada y aún sin decir si va bien. Se abre al cerrar el día.
  bool get sealed => hasAnswered && isCorrect == null && correctOption == null;
}

class QuizLivePayload {
  const QuizLivePayload({
    required this.state,
    this.round,
    this.prompt,
    this.imageUrl,
    this.audioUrl,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    this.explanation,
    this.answer,
    this.reveal,
  });

  /// idle | live | answered
  final String state;
  final QuizRound? round;
  final String? prompt;
  final String? imageUrl;
  final String? audioUrl;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String? explanation;
  final QuizAnswerState? answer;

  /// Resultado de la jornada ya cerrada, si quien juega aún no lo ha visto.
  final QuizDayReveal? reveal;

  bool get isLive => state == 'live';
  bool get isAnswered => state == 'answered';
  bool get isIdle => state == 'idle';

  bool get hasAudio {
    final u = audioUrl?.trim();
    return u != null && u.isNotEmpty;
  }
}

class QuizSubmitResult {
  const QuizSubmitResult({
    this.sealed = false,
    this.isCorrect,
    this.score,
    this.correctOption,
    this.selectedOption,
    this.explanation,
    this.forfeited = false,
    this.timedOut = false,
  });

  /// Guardada, sin decir aún si va bien.
  final bool sealed;
  final bool? isCorrect;
  final int? score;
  final QuizOption? correctOption;
  final QuizOption? selectedOption;
  final String? explanation;
  final bool forfeited;
  final bool timedOut;

  QuizSubmitResult copyWith({
    bool? sealed,
    bool? isCorrect,
    int? score,
    QuizOption? correctOption,
    QuizOption? selectedOption,
    String? explanation,
    bool? forfeited,
    bool? timedOut,
  }) {
    return QuizSubmitResult(
      sealed: sealed ?? this.sealed,
      isCorrect: isCorrect ?? this.isCorrect,
      score: score ?? this.score,
      correctOption: correctOption ?? this.correctOption,
      selectedOption: selectedOption ?? this.selectedOption,
      explanation: explanation ?? this.explanation,
      forfeited: forfeited ?? this.forfeited,
      timedOut: timedOut ?? this.timedOut,
    );
  }
}

class QuizRevealPlayer {
  const QuizRevealPlayer({required this.name, required this.correct});

  final String name;
  final bool correct;
}

/// Lo que se abre a las 00:00: la correcta y quién ha respondido.
class QuizDayReveal {
  const QuizDayReveal({
    required this.roundId,
    required this.prompt,
    this.imageUrl,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    this.explanation,
    this.selectedOption,
    this.correctOption,
    this.isCorrect,
    this.score,
    this.forfeited = false,
    this.timedOut = false,
    this.answeredCount = 0,
    this.correctCount = 0,
    this.players = const [],
  });

  final String roundId;
  final String prompt;
  final String? imageUrl;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String? explanation;
  final QuizOption? selectedOption;
  final QuizOption? correctOption;
  final bool? isCorrect;
  final int? score;
  final bool forfeited;
  final bool timedOut;
  final int answeredCount;
  final int correctCount;
  final List<QuizRevealPlayer> players;
}

class QuizLeaderboardEntry {
  const QuizLeaderboardEntry({
    required this.userId,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    required this.points,
    required this.answersCount,
    required this.correctCount,
    required this.rank,
  });

  final String userId;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final int points;
  final int answersCount;
  final int correctCount;
  final int rank;
}

/// Premio de un mes. Si [active] es falso, no se enseña a quien juega.
class QuizPrize {
  const QuizPrize({
    required this.yearMonth,
    required this.active,
    this.sponsorName = '',
    this.title = '',
    this.description = '',
    this.imageUrl,
    this.address = '',
    this.claimUntil,
  });

  final String yearMonth;
  final bool active;
  final String sponsorName;
  final String title;
  final String description;
  final String? imageUrl;
  final String address;
  final DateTime? claimUntil;

  bool get hasCopy {
    return title.trim().isNotEmpty || sponsorName.trim().isNotEmpty;
  }

  bool get visibleToPlayers => active && hasCopy;

  bool get claimStillOpen {
    if (claimUntil == null) return true;
    final today = DateTime.now();
    final end = DateTime(claimUntil!.year, claimUntil!.month, claimUntil!.day);
    final day = DateTime(today.year, today.month, today.day);
    return !day.isAfter(end);
  }

  String get monthLabel => quizMonthLabel(yearMonth);
}

/// Lo que se pinta en la pregunta y en el ranking.
class QuizPrizeShowcase {
  const QuizPrizeShowcase({this.stake, this.claimPrize, this.claimMe});

  /// Premio del mes en curso, si está activo.
  final QuizPrize? stake;

  /// Premio del mes ya cerrado, si sigue activo y en plazo.
  final QuizPrize? claimPrize;

  /// El usuario, cuando es el primero de ese mes.
  final QuizLeaderboardEntry? claimMe;

  bool get showClaim =>
      claimPrize != null &&
      claimPrize!.visibleToPlayers &&
      claimPrize!.claimStillOpen &&
      claimMe != null &&
      claimMe!.rank == 1;

  bool get showStake => stake != null && stake!.visibleToPlayers;

  bool get isEmpty => !showClaim && !showStake;
}

String quizMonthLabel(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) return yearMonth;
  const names = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  final year = parts[0];
  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) return yearMonth;
  return '${names[month - 1]} $year';
}

String quizYearMonthOf(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

class QuizSeasonInfo {
  const QuizSeasonInfo({this.startsOn, this.message});

  final DateTime? startsOn;
  final String? message;

  bool get hasContent {
    final msg = message?.trim();
    return startsOn != null || (msg != null && msg.isNotEmpty);
  }

  bool get startsInFuture {
    if (startsOn == null) return false;
    final today = DateTime.now();
    final startDay = DateTime(startsOn!.year, startsOn!.month, startsOn!.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return startDay.isAfter(todayDay);
  }
}

enum QuizRankingMode { top, around, above, below }

extension QuizRankingModeX on QuizRankingMode {
  String get apiValue => name;

  String get label => switch (this) {
        QuizRankingMode.around => 'Cerca de mí',
        QuizRankingMode.top => 'Top',
        QuizRankingMode.above => 'Por encima',
        QuizRankingMode.below => 'Por debajo',
      };
}

class QuizRankingBundle {
  const QuizRankingBundle({
    required this.yearMonth,
    required this.mode,
    required this.totalPlayers,
    this.me,
    required this.entries,
  });

  final String yearMonth;
  final QuizRankingMode mode;
  final int totalPlayers;
  final QuizLeaderboardEntry? me;
  final List<QuizLeaderboardEntry> entries;
}
