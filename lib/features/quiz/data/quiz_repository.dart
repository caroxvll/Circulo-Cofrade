import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../models/quiz_models.dart';

class QuizRepository {
  QuizRepository({SupabaseClient? client}) : _client = client;

  static const _imagesBucket = 'quiz-images';
  static const _audioBucket = 'quiz-audio';
  static const maxImageBytes = 500 * 1024;
  static const maxAudioBytes = 1024 * 1024;
  static const maxAudioSeconds = 20;
  static const seasonStartsOnConfigKey = 'quiz_season_starts_on';
  static const seasonMessageConfigKey = 'quiz_season_message';
  /// Si es `false`, oculta el acceso público a Pregunta en vivo.
  static const liveVisibleConfigKey = 'quiz_live_visible';

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<QuizLivePayload> fetchLivePayload() async {
    if (_client == null) return const QuizLivePayload(state: 'idle');

    final raw = await _client!.rpc('quiz_get_live_payload');
    return _livePayloadFromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<DateTime> openRound(String roundId) async {
    if (_client == null) throw const QuizUnavailableException();

    final raw = await _client!.rpc('quiz_open_round', params: {
      'p_round_id': roundId,
    });
    final map = Map<String, dynamic>.from(raw as Map);
    return DateTime.parse(map['openedAt'] as String).toLocal();
  }

  /// Abandono tras Empezar: cuenta como fallo (-40). Idempotente si ya respondió.
  Future<QuizSubmitResult?> forfeitRound(String roundId) async {
    if (_client == null) throw const QuizUnavailableException();

    final raw = await _client!.rpc('quiz_forfeit_round', params: {
      'p_round_id': roundId,
    });
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['forfeited'] != true && map['reason'] == 'not_opened') {
      return null;
    }
    final correct = quizOptionFromString(map['correctOption'] as String?);
    if (correct == null) return null;
    return QuizSubmitResult(
      isCorrect: map['isCorrect'] as bool? ?? false,
      score: (map['score'] as num?)?.toInt() ?? -40,
      correctOption: correct,
      selectedOption:
          quizOptionFromString(map['selectedOption'] as String?) ?? correct,
      explanation: map['explanation'] as String?,
      forfeited: map['forfeited'] == true,
    );
  }

  Future<QuizSubmitResult> submitAnswer({
    required String roundId,
    required QuizOption option,
  }) async {
    if (_client == null) throw const QuizUnavailableException();

    final raw = await _client!.rpc(
      'quiz_submit_answer',
      params: {
        'p_round_id': roundId,
        'p_option': quizOptionToString(option),
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    return QuizSubmitResult(
      isCorrect: map['isCorrect'] as bool? ?? false,
      score: (map['score'] as num?)?.toInt() ?? 0,
      correctOption: quizOptionFromString(map['correctOption'] as String?)!,
      selectedOption: quizOptionFromString(map['selectedOption'] as String?)!,
      explanation: map['explanation'] as String?,
    );
  }

  Future<List<QuizLeaderboardEntry>> fetchMonthlyLeaderboard({
    String? yearMonth,
  }) async {
    if (_client == null) return const [];

    final raw = await _client!.rpc(
      'quiz_monthly_leaderboard',
      params: {'p_year_month': yearMonth},
    );
    final rows = (raw as List).cast<Map<String, dynamic>>();
    return rows.map(_leaderboardFromRow).toList();
  }

  Future<QuizRankingBundle> fetchMonthlyRankingBundle({
    String? yearMonth,
    QuizRankingMode mode = QuizRankingMode.around,
    int limit = 40,
  }) async {
    if (_client == null) {
      return QuizRankingBundle(
        yearMonth: yearMonth ?? currentQuizYearMonthFallback(),
        mode: mode,
        totalPlayers: 0,
        entries: const [],
      );
    }

    final raw = await _client!.rpc(
      'quiz_monthly_ranking_bundle',
      params: {
        'p_year_month': yearMonth,
        'p_mode': mode.apiValue,
        'p_limit': limit,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    final entriesRaw = (map['entries'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final meRaw = map['me'] as Map<String, dynamic>?;
    final modeRaw = map['mode'] as String? ?? mode.apiValue;

    return QuizRankingBundle(
      yearMonth: map['yearMonth'] as String? ??
          yearMonth ??
          currentQuizYearMonthFallback(),
      mode: switch (modeRaw) {
        'top' => QuizRankingMode.top,
        'above' => QuizRankingMode.above,
        'below' => QuizRankingMode.below,
        _ => QuizRankingMode.around,
      },
      totalPlayers: (map['totalPlayers'] as num?)?.toInt() ?? 0,
      me: meRaw == null ? null : _leaderboardFromJson(meRaw),
      entries: entriesRaw.map(_leaderboardFromJson).toList(),
    );
  }

  Future<List<QuizQuestion>> fetchQuestionsForJunta() async {
    if (_client == null) return const [];

    final rows = await _client!
        .from('quiz_questions')
        .select()
        .order('created_at', ascending: false)
        .limit(100);

    return rows.map(_questionFromRow).toList();
  }

  /// Preguntas que ya tuvieron (o tienen) ronda live/closed.
  Future<Set<String>> fetchLaunchedQuestionIds() async {
    if (_client == null) return const {};

    final rows = await _client!
        .from('quiz_rounds')
        .select('question_id')
        .inFilter('status', ['live', 'closed']);

    return {
      for (final row in rows)
        if (row['question_id'] is String) row['question_id'] as String,
    };
  }

  Future<QuizQuestion> createQuestion({
    required String prompt,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required QuizOption correctOption,
    String? explanation,
    String? imageUrl,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    final uid = _client!.auth.currentUser?.id;
    if (uid == null) throw const QuizUnavailableException();

    final row = await _client!
        .from('quiz_questions')
        .insert({
          'prompt': prompt.trim(),
          'option_a': optionA.trim(),
          'option_b': optionB.trim(),
          'option_c': optionC.trim(),
          'option_d': optionD.trim(),
          'correct_option': quizOptionToString(correctOption),
          'explanation': explanation?.trim().isEmpty == true
              ? null
              : explanation?.trim(),
          'image_url': imageUrl,
          'status': 'pending_review',
          'created_by': uid,
        })
        .select()
        .single();

    return _questionFromRow(row);
  }

  Future<void> setQuestionStatus({
    required String questionId,
    required QuizQuestionStatus status,
    String? rejectionReason,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    final uid = _client!.auth.currentUser?.id;

    final patch = <String, dynamic>{
      'status': switch (status) {
        QuizQuestionStatus.draft => 'draft',
        QuizQuestionStatus.pendingReview => 'pending_review',
        QuizQuestionStatus.approved => 'approved',
        QuizQuestionStatus.rejected => 'rejected',
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status == QuizQuestionStatus.approved ||
        status == QuizQuestionStatus.rejected) {
      patch['reviewed_by'] = uid;
      patch['reviewed_at'] = DateTime.now().toUtc().toIso8601String();
      patch['rejection_reason'] = rejectionReason;
    }

    await _client!
        .from('quiz_questions')
        .update(patch)
        .eq('id', questionId);
  }

  Future<void> deleteQuestion(String questionId) async {
    if (_client == null) throw const QuizUnavailableException();
    await _client!.rpc('quiz_delete_question', params: {
      'p_question_id': questionId,
    });
  }

  Future<({int deleted, int skippedLive})> deleteQuestionsForMonth(
    String yearMonth,
  ) async {
    if (_client == null) throw const QuizUnavailableException();
    final raw = await _client!.rpc(
      'quiz_delete_questions_for_month',
      params: {'p_year_month': yearMonth},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    return (
      deleted: (map['deleted'] as num?)?.toInt() ?? 0,
      skippedLive: (map['skippedLive'] as num?)?.toInt() ?? 0,
    );
  }

  Future<QuizSeasonInfo> fetchSeasonInfo() async {
    if (_client == null) return const QuizSeasonInfo();
    final rows = await _client!
        .from('app_config')
        .select('key, value')
        .inFilter('key', [seasonStartsOnConfigKey, seasonMessageConfigKey]);
    String? startsRaw;
    String? message;
    for (final row in rows) {
      final key = row['key'] as String?;
      final value = (row['value'] as String?)?.trim();
      if (key == seasonStartsOnConfigKey) {
        startsRaw = (value == null || value.isEmpty) ? null : value;
      } else if (key == seasonMessageConfigKey) {
        message = (value == null || value.isEmpty) ? null : value;
      }
    }
    DateTime? startsOn;
    if (startsRaw != null) {
      startsOn = DateTime.tryParse(startsRaw);
      if (startsOn != null) {
        startsOn = DateTime(startsOn.year, startsOn.month, startsOn.day);
      }
    }
    return QuizSeasonInfo(startsOn: startsOn, message: message);
  }

  Future<void> saveSeasonInfo({
    DateTime? startsOn,
    String? message,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    final startsValue = startsOn == null
        ? ''
        : '${startsOn.year.toString().padLeft(4, '0')}-'
            '${startsOn.month.toString().padLeft(2, '0')}-'
            '${startsOn.day.toString().padLeft(2, '0')}';
    final msgValue = message?.trim() ?? '';
    final now = DateTime.now().toUtc().toIso8601String();
    await _client!.from('app_config').upsert([
      {
        'key': seasonStartsOnConfigKey,
        'value': startsValue,
        'updated_at': now,
      },
      {
        'key': seasonMessageConfigKey,
        'value': msgValue,
        'updated_at': now,
      },
    ]);
  }

  /// Visible para usuarios por defecto si la clave aún no existe.
  Future<bool> fetchLiveVisible() async {
    if (_client == null) return true;
    final row = await _client!
        .from('app_config')
        .select('value')
        .eq('key', liveVisibleConfigKey)
        .maybeSingle();
    final raw = (row?['value'] as String?)?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return true;
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  Future<void> saveLiveVisible(bool visible) async {
    if (_client == null) throw const QuizUnavailableException();
    await _client!.from('app_config').upsert({
      'key': liveVisibleConfigKey,
      'value': visible ? 'true' : 'false',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<QuizRound> launchRound(String questionId, {bool force = false}) async {
    if (_client == null) throw const QuizUnavailableException();

    final raw = await _client!.rpc(
      'quiz_launch_round',
      params: {
        'p_question_id': questionId,
        'p_force': force,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    return QuizRound(
      id: map['id'] as String,
      questionId: map['question_id'] as String,
      status: QuizRoundStatus.live,
      launchedAt: map['launched_at'] != null
          ? DateTime.parse(map['launched_at'] as String).toLocal()
          : null,
      closesAt: map['closes_at'] != null
          ? DateTime.parse(map['closes_at'] as String).toLocal()
          : null,
      answerSeconds: (map['answer_seconds'] as num?)?.toInt() ?? 15,
    );
  }

  Future<int> closeLiveRound() async {
    if (_client == null) throw const QuizUnavailableException();
    final raw = await _client!.rpc('quiz_close_live_round');
    final map = Map<String, dynamic>.from(raw as Map);
    return (map['closed'] as num?)?.toInt() ?? 0;
  }

  Future<void> attachQuestionImage({
    required String questionId,
    required String imageUrl,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    await _client!
        .from('quiz_questions')
        .update({
          'image_url': imageUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', questionId);
  }

  Future<void> attachQuestionAudio({
    required String questionId,
    required String audioUrl,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    await _client!
        .from('quiz_questions')
        .update({
          'audio_url': audioUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', questionId);
  }

  Future<Set<String>> fetchQuizAuthorIds() async {
    if (_client == null) return {};
    final rows = await _client!.from('quiz_authors').select('profile_id');
    return {
      for (final row in rows) row['profile_id'] as String,
    };
  }

  Future<bool> canCurrentUserCreateQuiz() async {
    if (_client == null) return false;
    final uid = _client!.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client!
        .from('quiz_authors')
        .select('profile_id')
        .eq('profile_id', uid)
        .maybeSingle();
    return row != null;
  }

  Future<void> setQuizAuthor({
    required String profileId,
    required bool enabled,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    final uid = _client!.auth.currentUser?.id;
    if (enabled) {
      await _client!.from('quiz_authors').upsert({
        'profile_id': profileId,
        'granted_by': uid,
      });
    } else {
      await _client!
          .from('quiz_authors')
          .delete()
          .eq('profile_id', profileId);
    }
  }

  Future<String> uploadQuestionImage({
    required String questionId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    if (bytes.length > maxImageBytes) {
      throw const QuizImageTooLargeException();
    }

    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final prepared = await prepareImageUploadAsync(
      rawBytes: bytes,
      extension: extension,
      contentType: mimeType,
      maxBytes: maxImageBytes,
      maxSide: 1200,
    );

    final path = '$questionId/cover.${prepared.extension}';
    await _client!.storage.from(_imagesBucket).uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: prepared.contentType,
          ),
        );
    final url = _client!.storage.from(_imagesBucket).getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadQuestionAudio({
    required String questionId,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
  }) async {
    if (_client == null) throw const QuizUnavailableException();
    if (bytes.length > maxAudioBytes) {
      throw const QuizAudioTooLargeException();
    }

    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = switch (ext) {
      'mp3' || 'mpeg' => 'mp3',
      'm4a' || 'mp4' || 'aac' => 'm4a',
      'wav' => 'wav',
      _ => 'm4a',
    };
    final path = '$questionId/clip.$safeExt';
    await _client!.storage.from(_audioBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );
    final url = _client!.storage.from(_audioBucket).getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  QuizLivePayload _livePayloadFromJson(Map<String, dynamic> json) {
    final state = json['state'] as String? ?? 'idle';
    final roundJson = json['round'] as Map<String, dynamic>?;
    final questionJson = json['question'] as Map<String, dynamic>?;
    final answerJson = json['answer'] as Map<String, dynamic>?;

    QuizRound? round;
    if (roundJson != null) {
      round = QuizRound(
        id: roundJson['id'] as String,
        questionId: questionJson?['id'] as String? ?? '',
        status: QuizRoundStatus.live,
        launchedAt: roundJson['launchedAt'] != null
            ? DateTime.parse(roundJson['launchedAt'] as String).toLocal()
            : null,
        closesAt: roundJson['closesAt'] != null
            ? DateTime.parse(roundJson['closesAt'] as String).toLocal()
            : null,
        answerSeconds: (roundJson['answerSeconds'] as num?)?.toInt() ?? 15,
      );
    }

    QuizAnswerState? answer;
    if (answerJson != null) {
      answer = QuizAnswerState(
        openedAt: answerJson['openedAt'] != null
            ? DateTime.parse(answerJson['openedAt'] as String).toLocal()
            : null,
        answeredAt: answerJson['answeredAt'] != null
            ? DateTime.parse(answerJson['answeredAt'] as String).toLocal()
            : null,
        selectedOption:
            quizOptionFromString(answerJson['selectedOption'] as String?),
        isCorrect: answerJson['isCorrect'] as bool?,
        score: (answerJson['score'] as num?)?.toInt(),
        correctOption:
            quizOptionFromString(answerJson['correctOption'] as String?),
      );
    }

    return QuizLivePayload(
      state: state,
      round: round,
      prompt: questionJson?['prompt'] as String?,
      imageUrl: questionJson?['imageUrl'] as String?,
      audioUrl: questionJson?['audioUrl'] as String?,
      optionA: questionJson?['optionA'] as String?,
      optionB: questionJson?['optionB'] as String?,
      optionC: questionJson?['optionC'] as String?,
      optionD: questionJson?['optionD'] as String?,
      explanation: questionJson?['explanation'] as String?,
      answer: answer,
    );
  }

  QuizQuestion _questionFromRow(Map<String, dynamic> row) {
    return QuizQuestion(
      id: row['id'] as String,
      prompt: row['prompt'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      audioUrl: row['audio_url'] as String?,
      optionA: row['option_a'] as String? ?? '',
      optionB: row['option_b'] as String? ?? '',
      optionC: row['option_c'] as String? ?? '',
      optionD: row['option_d'] as String? ?? '',
      correctOption:
          quizOptionFromString(row['correct_option'] as String?) ?? QuizOption.a,
      explanation: row['explanation'] as String?,
      status: switch (row['status'] as String?) {
        'draft' => QuizQuestionStatus.draft,
        'approved' => QuizQuestionStatus.approved,
        'rejected' => QuizQuestionStatus.rejected,
        _ => QuizQuestionStatus.pendingReview,
      },
      createdBy: row['created_by'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toLocal()
          : null,
      rejectionReason: row['rejection_reason'] as String?,
    );
  }

  QuizLeaderboardEntry _leaderboardFromRow(Map<String, dynamic> row) {
    return QuizLeaderboardEntry(
      userId: row['user_id'] as String,
      handle: row['handle'] as String? ?? '',
      displayName: row['display_name'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      points: (row['points'] as num?)?.toInt() ?? 0,
      answersCount: (row['answers_count'] as num?)?.toInt() ?? 0,
      correctCount: (row['correct_count'] as num?)?.toInt() ?? 0,
      rank: (row['rank'] as num?)?.toInt() ?? 0,
    );
  }

  QuizLeaderboardEntry _leaderboardFromJson(Map<String, dynamic> row) {
    return QuizLeaderboardEntry(
      userId: (row['userId'] ?? row['user_id']) as String,
      handle: row['handle'] as String? ?? '',
      displayName:
          (row['displayName'] ?? row['display_name']) as String? ?? '',
      avatarUrl: (row['avatarUrl'] ?? row['avatar_url']) as String?,
      points: (row['points'] as num?)?.toInt() ?? 0,
      answersCount:
          ((row['answersCount'] ?? row['answers_count']) as num?)?.toInt() ??
              0,
      correctCount:
          ((row['correctCount'] ?? row['correct_count']) as num?)?.toInt() ??
              0,
      rank: (row['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuizUnavailableException implements Exception {
  const QuizUnavailableException();
}

class QuizImageTooLargeException implements Exception {
  const QuizImageTooLargeException();
}

class QuizAudioTooLargeException implements Exception {
  const QuizAudioTooLargeException();
}

QuizRepository createQuizRepository() {
  return QuizRepository(client: SupabaseBootstrap.client);
}

String currentQuizYearMonthFallback() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  return '${now.year}-$m';
}
