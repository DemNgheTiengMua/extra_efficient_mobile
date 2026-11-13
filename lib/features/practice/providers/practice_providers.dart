import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/auth_provider.dart';
import '../../context/learner_context_provider.dart';
import '../models/practice_models.dart';

class PracticeRepository {
  PracticeRepository(this._dio);

  final Dio _dio;

  Future<PracticeCatalog> fetchCatalog() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/api/learner/practice/catalog');
    return PracticeCatalog.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// `GET /practice/matrix` is a bare array of cells, not an object.
  Future<PracticeMatrix> fetchMatrix() async {
    final res = await _dio.get<List<dynamic>>('/api/learner/practice/matrix');
    return PracticeMatrix.parse(res.data ?? const []);
  }

  /// Asks the backend whether a cell may start, before the learner taps it.
  Future<PracticeFreeDrillState> fetchFreeDrill({
    required int topicId,
    required String cefrLevelCode,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/practice/free-drill',
      queryParameters: {'topicId': topicId, 'cefrLevelCode': cefrLevelCode},
    );
    return PracticeFreeDrillState.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  Future<int> startSession({
    int? sectionId,
    int? topicId,
    String? cefrLevelCode,
    required PracticeQuestionSource questionSource,
    required PracticeFeedbackMode feedbackMode,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/practice/sessions',
      data: {
        'sectionId': ?sectionId,
        'topicId': ?topicId,
        'cefrLevelCode': ?cefrLevelCode,
        'questionSource': questionSource.apiValue,
        'feedbackMode': feedbackMode.apiValue,
      },
    );
    final data = res.data ?? const <String, dynamic>{};
    return (data['sessionId'] as num?)?.toInt() ?? 0;
  }

  Future<PracticeSessionTake> fetchSessionTake(int sessionId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/practice/sessions/$sessionId/take',
    );
    return PracticeSessionTake.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  Future<String> requestHint(int sessionId, int questionId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/practice/sessions/$sessionId/questions/$questionId/hint',
    );
    return res.data?['hint'] as String? ?? '';
  }

  Future<PracticeAnswerResult> submitAnswer(
    int sessionId,
    int questionId, {
    int? selectedOptionId,
    String? responseText,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/practice/sessions/$sessionId/questions/$questionId/answer',
      data: {
        'selectedOptionId': selectedOptionId,
        'responseText': ?responseText,
      },
    );
    return PracticeAnswerResult.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  Future<PracticeSummary> fetchSummary(int sessionId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/practice/sessions/$sessionId/summary',
    );
    return PracticeSummary.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<PracticeInsight> fetchInsight(int sessionId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/insights/practice/$sessionId',
    );
    return PracticeInsight.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<PracticeInsight> retryInsight(int sessionId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/insights/practice/$sessionId/retry',
    );
    return PracticeInsight.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<int> saveQuestion(int questionId, {String source = 'manual'}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/saved-questions/questions/$questionId',
      data: {'source': source},
    );
    return (res.data?['savedQuestionId'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteSavedQuestion(int savedQuestionId) async {
    await _dio.delete<void>('/api/learner/saved-questions/$savedQuestionId');
  }

  Future<SavedQuestionsResponse> fetchSavedQuestions({
    int? sectionId,
    int? categoryId,
    String? source,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/saved-questions',
      queryParameters: {
        'sectionId': ?sectionId,
        'categoryId': ?categoryId,
        'source': ?source,
      },
    );
    return SavedQuestionsResponse.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  Future<SavedQuestionDetail> fetchSavedQuestionDetail(
    int savedQuestionId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/saved-questions/$savedQuestionId',
    );
    return SavedQuestionDetail.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  Future<WeaknessAnalysisData> fetchWeaknessAnalysis() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/weakness-analysis',
    );
    return WeaknessAnalysisData.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  Future<bool> resolveRecommendation(int recId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/recommendations/$recId/resolve',
    );
    return res.data?['isResolved'] as bool? ?? false;
  }
}

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  return PracticeRepository(ref.watch(dioProvider));
});

class PracticeQuestionSourceNotifier extends Notifier<PracticeQuestionSource> {
  @override
  PracticeQuestionSource build() => PracticeQuestionSource.all;

  void select(PracticeQuestionSource source) => state = source;
}

final practiceQuestionSourceProvider =
    NotifierProvider<PracticeQuestionSourceNotifier, PracticeQuestionSource>(
  PracticeQuestionSourceNotifier.new,
);

class PracticeFeedbackModeNotifier extends Notifier<PracticeFeedbackMode> {
  @override
  PracticeFeedbackMode build() => PracticeFeedbackMode.immediate;

  void select(PracticeFeedbackMode mode) => state = mode;
}

final practiceFeedbackModeProvider =
    NotifierProvider<PracticeFeedbackModeNotifier, PracticeFeedbackMode>(
  PracticeFeedbackModeNotifier.new,
);

final practiceCatalogProvider =
    FutureProvider.autoDispose<PracticeCatalog>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) {
    return const PracticeCatalog();
  }
  return ref.read(practiceRepositoryProvider).fetchCatalog();
  // Retry is disabled here because a refused load must reach the screen's own
  // error branch; the app-wide stance is #12's.
}, retry: (count, error) => null);

final practiceMatrixProvider =
    FutureProvider.autoDispose<PracticeMatrix>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) {
    return const PracticeMatrix(levels: [], topics: []);
  }
  return ref.read(practiceRepositoryProvider).fetchMatrix();
}, retry: (count, error) => null);

/// The grid's own availability: the matrix cells plus the backend's lock state
/// for every cell, asked **before** the learner taps rather than discovered by a
/// failed start. Keyed `"<topicId>:<levelCode>"`.
class PracticeGrid {
  const PracticeGrid({required this.matrix, required this.locks});

  final PracticeMatrix matrix;
  final Map<String, PracticeFreeDrillState> locks;

  static String keyFor(int topicId, String levelCode) => '$topicId:$levelCode';

  PracticeFreeDrillState? lockFor(int topicId, String levelCode) =>
      locks[keyFor(topicId, levelCode)];
}

final practiceGridProvider =
    FutureProvider.autoDispose<PracticeGrid>((ref) async {
  final matrix = await ref.watch(practiceMatrixProvider.future);
  final repo = ref.read(practiceRepositoryProvider);
  final states = await Future.wait([
    for (final topic in matrix.topics)
      for (final cell in topic.cells)
        repo
            .fetchFreeDrill(
              topicId: cell.topicId,
              cefrLevelCode: cell.levelCode,
            )
            .then(
              (state) => MapEntry(
                PracticeGrid.keyFor(cell.topicId, cell.levelCode),
                state,
              ),
            ),
  ]);
  return PracticeGrid(matrix: matrix, locks: Map.fromEntries(states));
}, retry: (count, error) => null);

class SavedSectionFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}

final savedSectionFilterProvider =
    NotifierProvider<SavedSectionFilterNotifier, int?>(
  SavedSectionFilterNotifier.new,
);

class SavedCategoryFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}

final savedCategoryFilterProvider =
    NotifierProvider<SavedCategoryFilterNotifier, int?>(
  SavedCategoryFilterNotifier.new,
);

final savedQuestionsProvider =
    FutureProvider.autoDispose<SavedQuestionsResponse>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) {
    return const SavedQuestionsResponse(items: []);
  }
  final sectionId = ref.watch(savedSectionFilterProvider);
  final categoryId = ref.watch(savedCategoryFilterProvider);
  return ref.read(practiceRepositoryProvider).fetchSavedQuestions(
        sectionId: sectionId,
        categoryId: categoryId,
      );
});

final weaknessAnalysisProvider =
    FutureProvider.autoDispose<WeaknessAnalysisData>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) {
    return const WeaknessAnalysisData(
      hasData: false,
      sections: [],
      topics: [],
      recommendations: [],
    );
  }
  return ref.read(practiceRepositoryProvider).fetchWeaknessAnalysis();
});
