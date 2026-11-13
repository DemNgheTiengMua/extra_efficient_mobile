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

  Future<AiInsight> retryDashboardInsight({int? certId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/insights/dashboard/retry',
      queryParameters: certId != null ? {'certId': certId} : null,
    );
    return AiInsight.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<TargetBandGoal> fetchTargetBand() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/target-band',
    );
    return TargetBandGoal.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<TargetBandGoal> updateTargetBand(String targetBandCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/target-band',
      data: {'targetBandCode': targetBandCode},
    );
    return TargetBandGoal.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<TargetBandGoal> saveGoal({
    String? currentBandCode,
    required String targetBandCode,
    String? targetDate,
    num? weeklyStudyHours,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/goal',
      data: {
        'currentBandCode': currentBandCode,
        'targetBandCode': targetBandCode,
        'targetDate': targetDate,
        'weeklyStudyHours': weeklyStudyHours,
      },
    );
    return TargetBandGoal.fromJson(
      response.data ?? const <String, dynamic>{},
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

  Future<LearningPathOverview?> fetchLearningPath() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/learner/learning-path',
      );
      final data = response.data;
      if (data == null || data['hasPath'] == false) {
        return null;
      }
      return LearningPathOverview.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> generateLearningPath({String? targetBandCode}) async {
    await _dio.post<void>(
      '/api/learner/learning-path/generate',
      data: targetBandCode != null
          ? {'targetBandCode': targetBandCode}
          : <String, dynamic>{},
    );
  }

  Future<void> resetLearningPath() async {
    await _dio.post<void>('/api/learner/learning-path/reset');
  }

  Future<PathModuleItem> fetchStep(int stepId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/learning-path/steps/$stepId',
    );
    return PathModuleItem.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<PathModuleItem> startStep(int stepId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/learning-path/steps/$stepId/start',
    );
    return PathModuleItem.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<AiInsight> fetchPathInsight() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/learner/insights/path',
    );
    return AiInsight.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<AiInsight> retryPathInsight() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/learner/insights/path/retry',
    );
    return AiInsight.fromJson(response.data ?? const <String, dynamic>{});
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
