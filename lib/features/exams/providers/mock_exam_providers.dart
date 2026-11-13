import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/provider_retry.dart';
import '../../context/learner_context_provider.dart';
import '../data/mock_exam_repository.dart';
import '../models/mock_exam_models.dart';

final mockExamRepositoryProvider = Provider<MockExamRepository>((ref) {
  return MockExamRepository(ref.watch(dioProvider));
});

// Every read below names the app-wide no-retry stance (`_noRetry`): each has a
// visible RETRY control on screen, and Riverpod's default ten-attempt ladder
// would only report the same failure ~38 s later, as loading.
final mockExamsProvider = FutureProvider.autoDispose<MockExamCatalogue>((
  ref,
) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(mockExamRepositoryProvider).fetchCatalogue();
}, retry: noProviderRetry);

final examHistoryProvider = FutureProvider.autoDispose<ExamHistory>((
  ref,
) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(mockExamRepositoryProvider).fetchExamHistory();
}, retry: noProviderRetry);

final mockInstructionsProvider = FutureProvider.autoDispose
    .family<MockExamInstructions, int>((ref, examId) async {
      return ref.read(mockExamRepositoryProvider).fetchInstructions(examId);
    }, retry: noProviderRetry);

final mockResultProvider = FutureProvider.autoDispose
    .family<MockAttemptResult, int>((ref, attemptId) async {
      return ref.read(mockExamRepositoryProvider).fetchResult(attemptId);
    }, retry: noProviderRetry);

final examInsightProvider = FutureProvider.autoDispose
    .family<ExamAiInsight, int>((ref, attemptId) async {
      return ref.read(mockExamRepositoryProvider).fetchExamInsight(attemptId);
    }, retry: noProviderRetry);

final mockReviewProvider = FutureProvider.autoDispose
    .family<MockAttemptReview, int>((ref, attemptId) async {
      return ref.read(mockExamRepositoryProvider).fetchReview(attemptId);
    }, retry: noProviderRetry);
