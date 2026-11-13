import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/placement_models.dart';
import '../models/preflight_models.dart';

/// Repository for `/api/learner/placement*` endpoints.
class PlacementRepository {
  const PlacementRepository(this._dio);

  final Dio _dio;

  Future<PlacementCatalog> fetchCatalog() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement',
    );
    return PlacementCatalog.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<PlacementPreflight> fetchPreflight() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/preflight',
    );
    return PlacementPreflight.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  /// `GET /api/learner/placement/take/{id}/preflight` — the device gate's facts.
  ///
  /// Distinct from [fetchPreflight]: that one is the pre-start capability view.
  Future<PreflightStatus> fetchPreflightStatus(int placementId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/take/$placementId/preflight',
    );
    return PreflightStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  /// `POST /api/learner/attempts/{attemptId}/preflight/verify`.
  ///
  /// A placement has no verify route of its own; the sitting it adapts does, so
  /// the status payload's own `attemptId` is what this is called with.
  Future<PreflightStatus> verifyPreflight(int attemptId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/attempts/$attemptId/preflight/verify',
    );
    return PreflightStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<int> startPlacement({
    required int examId,
    required String scope,
    required bool reuseValidSkills,
    String? idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/placement/start',
      data: {
        'examId': examId,
        'scope': scope,
        'reuseValidSkills': reuseValidSkills,
        'idempotencyKey': idempotencyKey,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return (data['placementId'] as num?)?.toInt() ?? 0;
  }

  Future<PlacementSitting> fetchSitting(int placementId, {int? q}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/take/$placementId',
      queryParameters: q != null ? {'q': q} : null,
    );
    return PlacementSitting.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> saveAnswer(
    int placementId,
    int questionId, {
    required int? selectedOptionId,
    required bool isFlagged,
    String? responseText,
    String? selectedOptionIdsJson,
  }) async {
    await _dio.post<void>(
      '/api/learner/placement/take/$placementId/answers/$questionId',
      data: {
        'selectedOptionId': selectedOptionId,
        'isFlagged': isFlagged,
        'responseText': responseText,
        'selectedOptionIdsJson': selectedOptionIdsJson,
      },
    );
  }

  Future<void> saveDraft(
    int placementId, {
    required int questionId,
    required String? responseText,
  }) async {
    await _dio.post<void>(
      '/api/learner/placement/take/$placementId/draft',
      data: {'questionId': questionId, 'responseText': responseText},
    );
  }

  Future<void> uploadSpeakingAudio(
    int placementId,
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
      '/api/learner/speaking/attempts/$placementId/questions/$questionId/audio',
      data: formData,
    );
  }

  Future<void> reportRecordingInterruption(
    int placementId, {
    required int questionId,
    required String sessionToken,
    required int capturedMs,
  }) async {
    await _dio.post<void>(
      '/api/learner/placement/take/$placementId/recording-interruptions',
      data: {
        'questionId': questionId,
        'sessionToken': sessionToken,
        'capturedMs': capturedMs,
      },
    );
  }

  Future<void> abandon(int placementId) async {
    await _dio.post<void>('/api/learner/placement/take/$placementId/abandon');
  }

  Future<void> submit(int placementId, {bool isAutoSubmit = false}) async {
    await _dio.post<void>(
      '/api/learner/placement/take/$placementId/submit',
      data: {'isAutoSubmit': isAutoSubmit},
    );
  }

  Future<PlacementResult> fetchResult(int placementId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/result/$placementId',
    );
    return PlacementResult.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<PlacementResult> fetchResultStatus(int placementId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/result/$placementId/status',
    );
    return PlacementResult.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> retryGrading(int placementId) async {
    await _dio.post<void>('/api/learner/placement/result/$placementId/retry');
  }
}
