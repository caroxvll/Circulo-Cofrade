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
  });

  final DateTime? openedAt;
  final DateTime? answeredAt;
  final QuizOption? selectedOption;
  final bool? isCorrect;
  final int? score;
  final QuizOption? correctOption;

  bool get hasAnswered => answeredAt != null;
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
    required this.isCorrect,
    required this.score,
    required this.correctOption,
    required this.selectedOption,
    this.explanation,
    this.forfeited = false,
    this.timedOut = false,
  });

  final bool isCorrect;
  final int score;
  final QuizOption correctOption;
  final QuizOption selectedOption;
  final String? explanation;
  final bool forfeited;
  final bool timedOut;

  QuizSubmitResult copyWith({
    bool? isCorrect,
    int? score,
    QuizOption? correctOption,
    QuizOption? selectedOption,
    String? explanation,
    bool? forfeited,
    bool? timedOut,
  }) {
    return QuizSubmitResult(
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

/// Aviso de inicio de temporada en la pantalla idle del quiz.
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
