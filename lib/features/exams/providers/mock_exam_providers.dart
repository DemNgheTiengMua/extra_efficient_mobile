import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../context/learner_context_provider.dart';
import '../data/mock_exam_repository.dart';
import '../models/mock_exam_models.dart';

final mockExamRepositoryProvider = Provider<MockExamRepository>((ref) {
  return MockExamRepository(ref.watch(dioProvider));
});

/// These reads each have a visible RETRY control on screen, so Riverpod's
/// default ten-attempt, ~38-second retry would only delay the same answer.
/// A failure should reach the error branch immediately.
Duration? _noRetry(int retryCount, Object error) => null;

final mockExamsProvider = FutureProvider.autoDispose<MockExamCatalogue>((
  ref,
) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(mockExamRepositoryProvider).fetchCatalogue();
}, retry: _noRetry);

final examHistoryProvider = FutureProvider.autoDispose<ExamHistory>((
  ref,
) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(mockExamRepositoryProvider).fetchExamHistory();
}, retry: _noRetry);

final mockInstructionsProvider = FutureProvider.autoDispose
    .family<MockExamInstructions, int>((ref, examId) async {
      return ref.read(mockExamRepositoryProvider).fetchInstructions(examId);
    }, retry: _noRetry);

final mockPreflightProvider = FutureProvider.autoDispose
    .family<MockPreflight, int>((ref, attemptId) async {
      return ref.read(mockExamRepositoryProvider).fetchPreflight(attemptId);
    }, retry: _noRetry);

final mockResultProvider = FutureProvider.autoDispose
    .family<MockAttemptResult, int>((ref, attemptId) async {
      return ref.read(mockExamRepositoryProvider).fetchResult(attemptId);
    }, retry: _noRetry);

final examInsightProvider = FutureProvider.autoDispose
    .family<ExamAiInsight, int>((ref, attemptId) async {
      return ref.read(mockExamRepositoryProvider).fetchExamInsight(attemptId);
    }, retry: _noRetry);

final mockReviewProvider = FutureProvider.autoDispose
    .family<MockAttemptReview, int>((ref, attemptId) async {
      return ref.read(mockExamRepositoryProvider).fetchReview(attemptId);
    }, retry: _noRetry);
