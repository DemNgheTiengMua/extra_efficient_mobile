import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/auth_provider.dart';
import '../../context/learner_context_provider.dart';
import '../data/path_repository.dart';
import '../models/path_models.dart';

final pathRepositoryProvider = Provider<PathRepository>((ref) {
  return PathRepository(ref.watch(dioProvider));
});

final dashboardProvider = FutureProvider<LearnerDashboard?>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  ref.watch(certificateScopeVersionProvider);
  if (!auth.isAuthenticated) return null;
  return ref.watch(pathRepositoryProvider).fetchDashboard();
});

class DashboardInsightNotifier extends AsyncNotifier<AiInsight?> {
  @override
  Future<AiInsight?> build() async {
    final auth = ref.watch(authNotifierProvider);
    ref.watch(certificateScopeVersionProvider);
    if (!auth.isAuthenticated) return null;
    return ref.watch(pathRepositoryProvider).fetchDashboardInsight();
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(pathRepositoryProvider).retryDashboardInsight(),
    );
  }
}

final dashboardInsightProvider =
    AsyncNotifierProvider<DashboardInsightNotifier, AiInsight?>(
      DashboardInsightNotifier.new,
    );

class TargetBandGoalNotifier extends AsyncNotifier<TargetBandGoal?> {
  @override
  Future<TargetBandGoal?> build() async {
    final auth = ref.watch(authNotifierProvider);
    ref.watch(certificateScopeVersionProvider);
    if (!auth.isAuthenticated) return null;
    return ref.watch(pathRepositoryProvider).fetchTargetBand();
  }

  Future<void> updateTargetBand(String targetBandCode) async {
    final repo = ref.read(pathRepositoryProvider);
    await repo.updateTargetBand(targetBandCode);
    state = AsyncData(await repo.fetchTargetBand());
    ref.invalidate(dashboardProvider);
    // A target band is what a path is generated towards, so the path screen's
    // gate is now open.
    ref.invalidate(learningPathProvider);
  }

  Future<void> saveGoal({
    String? currentBandCode,
    required String targetBandCode,
    String? targetDate,
    num? weeklyStudyHours,
  }) async {
    final repo = ref.read(pathRepositoryProvider);
    await repo.saveGoal(
      currentBandCode: currentBandCode,
      targetBandCode: targetBandCode,
      targetDate: targetDate,
      weeklyStudyHours: weeklyStudyHours,
    );
    state = AsyncData(await repo.fetchTargetBand());
    ref.invalidate(dashboardProvider);
    ref.invalidate(learningPathProvider);
  }
}

final targetBandGoalProvider =
    AsyncNotifierProvider<TargetBandGoalNotifier, TargetBandGoal?>(
      TargetBandGoalNotifier.new,
    );

class CalibrationNotifier extends AsyncNotifier<CalibrationStatus?> {
  @override
  Future<CalibrationStatus?> build() async {
    final auth = ref.watch(authNotifierProvider);
    ref.watch(certificateScopeVersionProvider);
    if (!auth.isAuthenticated) return null;
    return ref.watch(pathRepositoryProvider).fetchCalibration();
  }

  Future<void> decide({required bool adjust}) async {
    final updated = await ref
        .read(pathRepositoryProvider)
        .submitCalibrationDecision(adjust: adjust);
    state = AsyncData(updated);
    ref.invalidate(targetBandGoalProvider);
    ref.invalidate(dashboardProvider);
  }
}

final calibrationProvider =
    AsyncNotifierProvider<CalibrationNotifier, CalibrationStatus?>(
      CalibrationNotifier.new,
    );

class LearningPathNotifier extends AsyncNotifier<LearningPathOverview?> {
  @override
  Future<LearningPathOverview?> build() async {
    final auth = ref.watch(authNotifierProvider);
    ref.watch(certificateScopeVersionProvider);
    if (!auth.isAuthenticated) return null;
    return ref.watch(pathRepositoryProvider).fetchLearningPath();
  }

  /// Generation needs a target band; the screen only offers this once one is
  /// set, so the 422 "no goal to build a path from" is not reachable from here.
  Future<void> generate() async {
    state = const AsyncLoading();
    final repo = ref.read(pathRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.generateLearningPath();
      return repo.fetchLearningPath();
    });
    ref.invalidate(pathInsightProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> reset() async {
    state = const AsyncLoading();
    await ref.read(pathRepositoryProvider).resetLearningPath();
    ref.invalidate(dashboardProvider);
    ref.invalidateSelf();
  }
}

final learningPathProvider =
    AsyncNotifierProvider<LearningPathNotifier, LearningPathOverview?>(
      LearningPathNotifier.new,
      // A failed load must reach the screen's error branch rather than spin for
      // 38 s of invisible retries.
      retry: (_, _) => null,
    );

class PathInsightNotifier extends AsyncNotifier<AiInsight?> {
  @override
  Future<AiInsight?> build() async {
    final auth = ref.watch(authNotifierProvider);
    ref.watch(certificateScopeVersionProvider);
    if (!auth.isAuthenticated) return null;
    // The screen only watches this provider once an active path exists, because
    // `GET /insights/path` answers 404 LEARNING_PATH_NOT_FOUND without one.
    return ref.watch(pathRepositoryProvider).fetchPathInsight();
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(pathRepositoryProvider).retryPathInsight(),
    );
  }
}

final pathInsightProvider =
    AsyncNotifierProvider<PathInsightNotifier, AiInsight?>(
      PathInsightNotifier.new,
    );

final lessonDetailProvider = FutureProvider.family<LessonDetail?, int>((
  ref,
  lessonId,
) async {
  final auth = ref.watch(authNotifierProvider);
  ref.watch(certificateScopeVersionProvider);
  if (!auth.isAuthenticated) return null;
  return ref.watch(pathRepositoryProvider).fetchLesson(lessonId);
});

final lessonProgressProvider = FutureProvider.family<LessonProgress?, int>((
  ref,
  lessonId,
) async {
  final auth = ref.watch(authNotifierProvider);
  ref.watch(certificateScopeVersionProvider);
  if (!auth.isAuthenticated) return null;
  return ref.watch(pathRepositoryProvider).fetchLessonProgress(lessonId);
});
