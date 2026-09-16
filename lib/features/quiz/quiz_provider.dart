import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../permissions/permissions_provider.dart';
import 'data/quiz_repository.dart';
import 'models/quiz_models.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return createQuizRepository();
});

final quizLivePayloadProvider =
    FutureProvider.autoDispose<QuizLivePayload>((ref) async {
  return ref.watch(quizRepositoryProvider).fetchLivePayload();
});

final quizMonthlyLeaderboardProvider =
    FutureProvider.autoDispose<List<QuizLeaderboardEntry>>((ref) async {
  return ref.watch(quizRepositoryProvider).fetchMonthlyLeaderboard();
});

class QuizRankingModeNotifier extends Notifier<QuizRankingMode> {
  @override
  QuizRankingMode build() => QuizRankingMode.around;

  void setMode(QuizRankingMode mode) => state = mode;
}

final quizRankingModeProvider =
    NotifierProvider<QuizRankingModeNotifier, QuizRankingMode>(
  QuizRankingModeNotifier.new,
);

final quizMonthlyRankingBundleProvider =
    FutureProvider.autoDispose<QuizRankingBundle>((ref) async {
  final mode = ref.watch(quizRankingModeProvider);
  return ref.watch(quizRepositoryProvider).fetchMonthlyRankingBundle(
        mode: mode,
      );
});

final juntaQuizQuestionsProvider =
    FutureProvider.autoDispose<List<QuizQuestion>>((ref) async {
  return ref.watch(quizRepositoryProvider).fetchQuestionsForJunta();
});

final juntaQuizLaunchedIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  return ref.watch(quizRepositoryProvider).fetchLaunchedQuestionIds();
});

final quizAuthorIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  return ref.watch(quizRepositoryProvider).fetchQuizAuthorIds();
});

/// Admin siempre; moderador solo si está en quiz_authors.
final canCreateQuizQuestionsProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  final authors = ref.watch(quizAuthorIdsProvider).asData?.value;
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null || authors == null) {
    // Fallback async-aware: also check dedicated future below for first paint.
    return false;
  }
  return authors.contains(userId);
});

final canCreateQuizQuestionsAsyncProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  if (ref.watch(isAdminProvider)) return true;
  return ref.watch(quizRepositoryProvider).canCurrentUserCreateQuiz();
});

final quizSeasonInfoProvider =
    FutureProvider.autoDispose<QuizSeasonInfo>((ref) async {
  return ref.watch(quizRepositoryProvider).fetchSeasonInfo();
});

/// Si es false, se oculta el FAB y el acceso público a /quiz.
final quizLiveVisibleProvider = FutureProvider.autoDispose<bool>((ref) async {
  return ref.watch(quizRepositoryProvider).fetchLiveVisible();
});

String currentQuizYearMonth() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  return '${now.year}-$m';
}
