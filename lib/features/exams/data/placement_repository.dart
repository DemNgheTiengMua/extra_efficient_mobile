import 'package:dio/dio.dart';

import '../models/placement_models.dart';

/// Repository for `/api/learner/placement*` endpoints.
class PlacementRepository {
  const PlacementRepository(this._dio);

  final Dio _dio;

  Future<PlacementOverview> fetchOverview() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/learner/placement');
    return PlacementOverview.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<PlacementPreflight> fetchPreflight() async {
    final response = await _dio
        .get<Map<String, dynamic>>('/api/learner/placement/preflight');
    return PlacementPreflight.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<PlacementPreflight> fetchAttemptPreflight(int placementId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/take/$placementId/preflight',
    );
    return PlacementPreflight.fromJson(
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

  Future<PlacementSitting> resumeSitting(int placementId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/take/$placementId/resume',
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
      data: {
        'questionId': questionId,
        'responseText': responseText,
      },
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

  Future<void> submit(
    int placementId, {
    bool isAutoSubmit = false,
  }) async {
    await _dio.post<void>(
      '/api/learner/placement/take/$placementId/submit',
      data: {'isAutoSubmit': isAutoSubmit},
    );
  }

  Future<PlacementResult> fetchResult(int placementId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/result/$placementId',
    );
    return PlacementResult.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<PlacementResult> fetchResultStatus(int placementId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/placement/result/$placementId/status',
    );
    return PlacementResult.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> retryGrading(int placementId) async {
    await _dio.post<void>('/api/learner/placement/result/$placementId/retry');
  }
}
