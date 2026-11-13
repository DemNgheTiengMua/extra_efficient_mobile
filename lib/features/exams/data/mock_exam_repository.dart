import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/mock_exam_models.dart';
import '../models/placement_models.dart';
import '../models/preflight_models.dart';

/// Repository for `/api/learner/exams*` and `/api/learner/attempts*`.
class MockExamRepository {
  const MockExamRepository(this._dio);

  final Dio _dio;

  Future<MockExamCatalogue> fetchCatalogue() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/learner/exams');
    return MockExamCatalogue.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<ExamHistory> fetchExamHistory() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/exams/history',
    );
    return ExamHistory.fromJson(response.data ?? const <String, dynamic>{});
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

  /// `GET /api/learner/attempts/{id}/preflight` — the device gate's facts.
  Future<PreflightStatus> fetchPreflightStatus(int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/preflight',
    );
    return PreflightStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  /// `POST /api/learner/attempts/{id}/preflight/verify` — opens the sitting.
  ///
  /// Answers 200 with the same [PreflightStatus], now `isVerified: true`.
  Future<PreflightStatus> verifyPreflight(int attemptId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/preflight/verify',
    );
    return PreflightStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<PlacementSitting> fetchAttemptState(int attemptId, {int? q}) async {
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
      data: {'questionId': questionId, 'responseText': responseText},
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

  Future<Map<String, dynamic>> transitionSkill(int attemptId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/transition/skill',
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> transitionUnit(
    int attemptId,
    int targetUnitNumber,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/transition/unit',
      data: {'targetUnitNumber': targetUnitNumber},
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> transitionGroup(
    int attemptId,
    int targetGroupId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/transition/group',
      data: {'targetGroupId': targetGroupId},
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> startAudioReview(int attemptId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/audio-review/start',
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<void> uploadSpeakingAudio(
    int attemptId,
    int questionId,
    String filePath, {
    int? durationMs,
  }) async {
    final file = File(filePath);
    final multipart = file.existsSync()
        ? await MultipartFile.fromFile(filePath, filename: 'recording.m4a')
        : MultipartFile.fromBytes(
            utf8.encode('audio-recording'),
            filename: 'recording.m4a',
          );
    final formData = FormData.fromMap({
      'audioFile': multipart,
      'durationMs': ?durationMs,
    });
    await _dio.post<void>(
      '/api/learner/speaking/attempts/$attemptId/questions/$questionId/audio',
      data: formData,
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
    return ExamAiInsight.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<ExamAiInsight> retryExamInsight(int attemptId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/insights/exam/$attemptId/retry',
    );
    return ExamAiInsight.fromJson(response.data ?? const <String, dynamic>{});
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
