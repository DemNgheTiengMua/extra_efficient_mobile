import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/provider_retry.dart';
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

  /// `StartPracticeRequest` accepts a section **or** a (topic, level) cell,
  /// plus an optional content tier. It accepts no question source and no
  /// feedback mode — sending them is silently ignored, which is why the room
  /// offers neither.
  Future<int> startSession({
    int? sectionId,
    int? topicId,
    String? cefrLevelCode,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/practice/sessions',
      data: {
        'sectionId': ?sectionId,
        'topicId': ?topicId,
        'cefrLevelCode': ?cefrLevelCode,
      },
    );
    final data = res.data ?? const <String, dynamic>{};
    return (data['sessionId'] as num?)?.toInt() ?? 0;
  }

  /// The composite: session, current question, every question, navigator.
  Future<PracticeSessionTake> fetchSessionTake(int sessionId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/practice/sessions/$sessionId/take',
    );
    return PracticeSessionTake.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  /// `address`, not `questionId`: a pool item has no row id and sending `0`
  /// answers nothing.
  Future<String> requestHint(int sessionId, int address) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/practice/sessions/$sessionId/questions/$address/hint',
      data: const <String, dynamic>{},
    );
    return res.data?['hint'] as String? ?? '';
  }

  Future<PracticeAnswerResult> submitAnswer(
    int sessionId,
    int address, {
    int? selectedOptionId,
    String? responseText,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/learner/practice/sessions/$sessionId/questions/$address/answer',
      data: {
        'selectedOptionId': ?selectedOptionId,
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

  /// Saves by whichever address the question actually holds. A question row and
  /// an item version are two separate id counters on the backend, so sending
  /// one to the other's route files the wrong thing (or nothing).
  Future<SavedQuestionResult> saveQuestionAddress({
    int? questionId,
    int? itemVersionId,
    String source = 'manual',
  }) async {
    final path = questionId != null
        ? '/api/learner/saved-questions/questions/$questionId'
        : itemVersionId != null
            ? '/api/learner/saved-questions/item-versions/$itemVersionId'
            : throw StateError('Question carries no address');
    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: {'source': source},
    );
    return SavedQuestionResult.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// DELETE answers 200 with the same result shape and `isSaved: false`.
  Future<SavedQuestionResult> deleteSavedQuestion(int savedQuestionId) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/api/learner/saved-questions/$savedQuestionId',
    );
    return SavedQuestionResult.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<SavedQuestionsResponse> fetchSavedQuestions() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/saved-questions',
    );
    return SavedQuestionsResponse.fromJson(
      res.data ?? const <String, dynamic>{},
    );
  }

  Future<SavedQuestionItem> fetchSavedQuestionDetail(
    int savedQuestionId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/learner/saved-questions/$savedQuestionId',
    );
    return SavedQuestionItem.fromJson(
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

final practiceCatalogProvider =
    FutureProvider.autoDispose<PracticeCatalog>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) {
    return const PracticeCatalog();
  }
  return ref.read(practiceRepositoryProvider).fetchCatalog();
}, retry: noProviderRetry);

final practiceMatrixProvider =
    FutureProvider.autoDispose<PracticeMatrix>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) {
    return const PracticeMatrix(levels: [], topics: []);
  }
  return ref.read(practiceRepositoryProvider).fetchMatrix();
}, retry: noProviderRetry);

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
}, retry: noProviderRetry);

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

/// SAVED. The backend builds the two facet lists but applies neither to the
/// list (`?sectionId=` / `?categoryId=` are ignored by the endpoint), so the
/// chips narrow the fetched rows here rather than pretending a query did it.
/// Live both lists are empty, because a pool item is section- and category-free.
final savedQuestionsProvider =
    FutureProvider.autoDispose<SavedQuestionsResponse>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) {
    return const SavedQuestionsResponse();
  }
  return ref.read(practiceRepositoryProvider).fetchSavedQuestions();
}, retry: noProviderRetry);

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
}, retry: noProviderRetry);
