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
    final updated = await ref
        .read(pathRepositoryProvider)
        .updateTargetBand(targetBandCode);
    state = AsyncData(updated);
    ref.invalidate(dashboardProvider);
  }

  Future<void> saveGoal({
    String? currentBandCode,
    required String targetBandCode,
    String? targetDate,
    num? weeklyStudyHours,
  }) async {
    final updated = await ref.read(pathRepositoryProvider).saveGoal(
          currentBandCode: currentBandCode,
          targetBandCode: targetBandCode,
          targetDate: targetDate,
          weeklyStudyHours: weeklyStudyHours,
        );
    state = AsyncData(updated);
    ref.invalidate(dashboardProvider);
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

  Future<void> generate({String? targetBandCode}) async {
    state = const AsyncLoading();
    await ref
        .read(pathRepositoryProvider)
        .generateLearningPath(targetBandCode: targetBandCode);
    state = await AsyncValue.guard(
      () => ref.read(pathRepositoryProvider).fetchLearningPath(),
    );
    ref.invalidate(pathInsightProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> reset() async {
    state = const AsyncLoading();
    await ref.read(pathRepositoryProvider).resetLearningPath();
    state = const AsyncData(null);
    ref.invalidate(dashboardProvider);
  }

  Future<PathModuleItem> startStep(int stepId) async {
    final repo = ref.read(pathRepositoryProvider);
    await repo.fetchStep(stepId);
    final started = await repo.startStep(stepId);
    ref.invalidateSelf();
    return started;
  }
}

final learningPathProvider =
    AsyncNotifierProvider<LearningPathNotifier, LearningPathOverview?>(
  LearningPathNotifier.new,
);

class PathInsightNotifier extends AsyncNotifier<AiInsight?> {
  @override
  Future<AiInsight?> build() async {
    final auth = ref.watch(authNotifierProvider);
    ref.watch(certificateScopeVersionProvider);
    if (!auth.isAuthenticated) return null;
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

final lessonDetailProvider =
    FutureProvider.family<LessonDetail?, int>((ref, lessonId) async {
  final auth = ref.watch(authNotifierProvider);
  ref.watch(certificateScopeVersionProvider);
  if (!auth.isAuthenticated) return null;
  return ref.watch(pathRepositoryProvider).fetchLesson(lessonId);
});

final lessonProgressProvider =
    FutureProvider.family<LessonProgress?, int>((ref, lessonId) async {
  final auth = ref.watch(authNotifierProvider);
  ref.watch(certificateScopeVersionProvider);
  if (!auth.isAuthenticated) return null;
  return ref.watch(pathRepositoryProvider).fetchLessonProgress(lessonId);
});
