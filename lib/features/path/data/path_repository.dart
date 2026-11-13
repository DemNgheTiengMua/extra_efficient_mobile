import 'package:dio/dio.dart';

import '../models/path_models.dart';

class PathRepository {
  PathRepository(this._dio);

  final Dio _dio;

  Future<LearnerDashboard> fetchDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/dashboard',
    );
    return LearnerDashboard.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<AiInsight> fetchDashboardInsight({int? certId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/insights/dashboard',
      queryParameters: certId != null ? {'certId': certId} : null,
    );
    return AiInsight.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Retry answers `204 No Content`, so the refreshed insight is fetched again.
  Future<AiInsight> retryDashboardInsight({int? certId}) async {
    await _dio.post<void>(
      '/api/learner/insights/dashboard/retry',
      queryParameters: certId != null ? {'certId': certId} : null,
    );
    return fetchDashboardInsight(certId: certId);
  }

  Future<TargetBandView> fetchTargetBand() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/target-band',
    );
    return TargetBandView.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> updateTargetBand(String targetBandCode) async {
    await _dio.post<void>(
      '/api/learner/target-band',
      data: {'targetBandCode': targetBandCode},
    );
  }

  Future<void> saveGoal({
    String? currentBandCode,
    required String targetBandCode,
    String? targetDate,
    num? weeklyStudyHours,
  }) async {
    await _dio.post<void>(
      '/api/learner/goal',
      data: {
        'currentBandCode': currentBandCode,
        'targetBandCode': targetBandCode,
        'targetDate': targetDate,
        'weeklyStudyHours': weeklyStudyHours,
      },
    );
  }

  Future<CalibrationStatus> fetchCalibration() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/calibration',
    );
    return CalibrationStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<CalibrationStatus> submitCalibrationDecision({
    required bool adjust,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/calibration/decision',
      data: {'adjust': adjust},
    );
    return CalibrationStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  /// `GET /learning-path` is the existence switch: `hasActivePath: false` means
  /// there is no path to show.
  Future<LearningPathOverview> fetchLearningPath() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/learning-path',
    );
    return LearningPathOverview.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  /// `POST /learning-path/generate` needs a target band: without one the
  /// backend answers 422 `LEARNING_PATH_BAND_UNKNOWN`. The screen gates on that
  /// rather than offering a button that always fails.
  Future<void> generateLearningPath({String? targetBandCode}) async {
    await _dio.post<void>(
      '/api/learner/learning-path/generate',
      data: targetBandCode != null
          ? {'targetBandCode': targetBandCode}
          : const <String, dynamic>{},
    );
  }

  Future<void> resetLearningPath() async {
    await _dio.post<void>('/api/learner/learning-path/reset');
  }

  /// A step that is not on the active path is a terminal "not available", so
  /// the 404 is translated instead of surfacing as a retryable failure.
  Future<PathStep> fetchStep(int stepId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/learner/learning-path/steps/$stepId',
      );
      return PathStep.fromJson(response.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw _stepError(e, stepId);
    }
  }

  Future<StartStepResult> startStep(int stepId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/learner/learning-path/steps/$stepId/start',
      );
      return StartStepResult.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw _stepError(e, stepId);
    }
  }

  /// 404 `LEARNING_PATH_STEP_NOT_FOUND` is terminal, not a network fault.
  Object _stepError(DioException e, int stepId) {
    final data = e.response?.data;
    final code = data is Map ? data['code']?.toString() : null;
    if (e.response?.statusCode == 404 &&
        code?.toLowerCase() == 'learning_path_step_not_found') {
      return PathStepUnavailable('Step $stepId is not on your active path.');
    }
    return e;
  }

  /// `GET /insights/path` answers `404 LEARNING_PATH_NOT_FOUND` whenever there
  /// is no active path. That is a designed empty state, so it maps to null and
  /// is never surfaced as an error.
  Future<AiInsight?> fetchPathInsight() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/learner/insights/path',
      );
      return AiInsight.fromJson(response.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Retry answers `204 No Content`, so the refreshed insight is fetched again.
  Future<AiInsight?> retryPathInsight() async {
    await _dio.post<void>('/api/learner/insights/path/retry');
    return fetchPathInsight();
  }

  Future<LessonDetail> fetchLesson(int id, {String? module}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/lessons/$id',
      queryParameters: module != null ? {'module': module} : null,
    );
    return LessonDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<LessonDetail> fetchLessonByCell({
    int? skillId,
    int? topicId,
    String? level,
    String? module,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/lessons/cell',
      queryParameters: {
        'skillId': ?skillId,
        'topicId': ?topicId,
        'level': ?level,
        'module': ?module,
      },
    );
    return LessonDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<List<LessonDetail>> fetchLessonsByCategory(int categoryId) async {
    final response = await _dio.get<dynamic>(
      '/api/learner/lessons/by-category/$categoryId',
    );
    final raw = response.data;
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LessonDetail.fromJson)
          .toList(growable: false);
    }
    return const [];
  }

  Future<LessonProgress> fetchLessonProgress(int id, {String? module}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/lessons/$id/progress',
      queryParameters: module != null ? {'module': module} : null,
    );
    return LessonProgress.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<LessonProgress> markCardViewed(int lessonId, int cardId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/lessons/$lessonId/cards/$cardId/view',
    );
    return LessonProgress.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<MicroCheckResult> submitMicroCheck({
    required int lessonId,
    required int cardId,
    required String selectedOption,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/lessons/$lessonId/cards/$cardId/micro-check',
      data: {'selectedOption': selectedOption},
    );
    return MicroCheckResult.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}
