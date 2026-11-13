import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/skill_practice_models.dart';

/// Repository for `/api/learner/skill-practice/*`, `/api/learner/speaking/*`,
/// and `/api/learner/writing/*`.
class SkillPracticeRepository {
  const SkillPracticeRepository(this._dio);

  final Dio _dio;

  Future<List<SkillPracticeExamSummary>> fetchCatalog(String skill) async {
    final response =
        await _dio.get<dynamic>('/api/learner/skill-practice/$skill');
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
        .map(SkillPracticeExamSummary.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchInstructions(
    String skill,
    int examId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/$skill/$examId/instructions',
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<int> startAttempt(String skill, int examId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/$skill/$examId/start',
    );
    final data = response.data ?? const <String, dynamic>{};
    return (data['attemptId'] as num?)?.toInt() ??
        (data['id'] as num?)?.toInt() ??
        0;
  }

  Future<SkillPracticeAttempt> fetchAttempt(String skill, int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/$skill/attempts/$attemptId',
    );
    return SkillPracticeAttempt.fromJson(
      response.data ?? const <String, dynamic>{},
    );
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

  Future<void> saveWritingDraft(
    int attemptId, {
    required int questionId,
    required String responseText,
  }) async {
    await _dio.post<void>(
      '/api/learner/writing/attempts/$attemptId/draft',
      data: {
        'questionId': questionId,
        'responseText': responseText,
      },
    );
  }

  Future<void> submitAttempt(String skill, int attemptId) async {
    await _dio.post<void>('/api/learner/$skill/attempts/$attemptId/submit');
  }

  Future<SkillPracticePendingStatus> fetchPending(
    String skill,
    int attemptId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/$skill/attempts/$attemptId/pending',
    );
    return SkillPracticePendingStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> retryGrading(String skill, int attemptId) async {
    await _dio.post<void>('/api/learner/$skill/attempts/$attemptId/retry');
  }

  Future<SkillPracticeReview> fetchReview(String skill, int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/$skill/attempts/$attemptId/review',
    );
    return SkillPracticeReview.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}
