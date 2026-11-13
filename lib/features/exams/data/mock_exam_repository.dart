import 'package:dio/dio.dart';

import '../models/mock_exam_models.dart';
import '../models/placement_models.dart';

/// Repository for `/api/learner/exams*` and `/api/learner/attempts*`.
class MockExamRepository {
  const MockExamRepository(this._dio);

  final Dio _dio;

  Future<List<MockExamSummary>> fetchMockExams() async {
    final response =
        await _dio.get<dynamic>('/api/learner/exams');
    final data = response.data;
    final list = data is List
        ? data
        : (data is Map<String, dynamic>
            ? (data['exams'] as List<dynamic>? ??
                data['items'] as List<dynamic>? ??
                const [])
            : const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(MockExamSummary.fromJson)
        .toList();
  }

  Future<List<ExamHistoryItem>> fetchExamHistory() async {
    final response =
        await _dio.get<dynamic>('/api/learner/exams/history');
    final data = response.data;
    final list = data is List
        ? data
        : (data is Map<String, dynamic>
            ? (data['attempts'] as List<dynamic>? ??
                data['items'] as List<dynamic>? ??
                const [])
            : const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(ExamHistoryItem.fromJson)
        .toList();
  }

  Future<MockExamInstructions> fetchInstructions(int examId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/exams/$examId/instructions',
    );
    return MockExamInstructions.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<int> startAttempt(int examId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/exams/$examId/start',
    );
    final data = response.data ?? const <String, dynamic>{};
    return (data['attemptId'] as num?)?.toInt() ??
        (data['id'] as num?)?.toInt() ??
        0;
  }

  Future<int> resumeByAuthorizationCode(String authorizationCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/attempts/resume',
      data: {'authorizationCode': authorizationCode},
    );
    final data = response.data ?? const <String, dynamic>{};
    return (data['attemptId'] as num?)?.toInt() ??
        (data['id'] as num?)?.toInt() ??
        0;
  }

  Future<MockPreflight> fetchPreflight(int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/preflight',
    );
    return MockPreflight.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> verifyPreflight(int attemptId) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/preflight/verify',
    );
  }

  Future<PlacementSitting> fetchAttemptSitting(int attemptId, {int? q}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId',
      queryParameters: q != null ? {'q': q} : null,
    );
    return PlacementSitting.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> saveAttemptAnswer(
    int attemptId,
    int questionId, {
    required int? selectedOptionId,
    required bool isFlagged,
    String? responseText,
    String? selectedOptionIdsJson,
  }) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/answers/$questionId',
      data: {
        'selectedOptionId': selectedOptionId,
        'isFlagged': isFlagged,
        'responseText': responseText,
        'selectedOptionIdsJson': selectedOptionIdsJson,
      },
    );
  }

  Future<void> saveAttemptDraft(
    int attemptId, {
    required int questionId,
    required String? responseText,
  }) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/draft',
      data: {
        'questionId': questionId,
        'responseText': responseText,
      },
    );
  }

  Future<void> syncSitting(
    int attemptId, {
    List<Map<String, dynamic>>? answers,
    int? lastAudioOffsetMs,
    int? lastQuestionId,
  }) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/sync',
      data: {
        'answers': answers,
        'lastAudioOffsetMs': lastAudioOffsetMs,
        'lastQuestionId': lastQuestionId,
      },
    );
  }

  Future<void> transitionSkill(int attemptId) async {
    await _dio.post<void>('/api/learner/attempts/$attemptId/transition/skill');
  }

  Future<void> transitionUnit(int attemptId, int targetUnitNumber) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/transition/unit',
      data: {'targetUnitNumber': targetUnitNumber},
    );
  }

  Future<void> transitionGroup(int attemptId, int targetGroupId) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/transition/group',
      data: {'targetGroupId': targetGroupId},
    );
  }

  Future<void> startAudioReview(int attemptId) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/audio-review/start',
    );
  }

  Future<void> submitAttempt(int attemptId) async {
    await _dio.post<void>('/api/learner/attempts/$attemptId/submit');
  }

  Future<void> submitAttemptWithDrafts(
    int attemptId,
    List<Map<String, dynamic>> drafts,
  ) async {
    await _dio.post<void>(
      '/api/learner/attempts/$attemptId/submit-with-drafts',
      data: {'drafts': drafts},
    );
  }

  Future<void> cancelAttempt(int attemptId) async {
    await _dio.post<void>('/api/learner/attempts/$attemptId/cancel');
  }

  Future<MockAttemptResult> fetchResult(int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/result',
    );
    return MockAttemptResult.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<ExamAiInsight> fetchExamInsight(int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/insights/exam/$attemptId',
    );
    return ExamAiInsight.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<ExamAiInsight> retryExamInsight(int attemptId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/insights/exam/$attemptId/retry',
    );
    return ExamAiInsight.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<MockAttemptReview> fetchReview(int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/review',
    );
    return MockAttemptReview.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> saveQuestion(int questionId) async {
    await _dio.post<void>(
      '/api/learner/saved-questions/questions/$questionId',
      data: const <String, dynamic>{},
    );
  }
}
