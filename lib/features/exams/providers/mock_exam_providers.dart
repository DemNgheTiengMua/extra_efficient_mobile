import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../context/learner_context_provider.dart';
import '../data/mock_exam_repository.dart';
import '../models/mock_exam_models.dart';

final mockExamRepositoryProvider = Provider<MockExamRepository>((ref) {
  return MockExamRepository(ref.watch(dioProvider));
});

final mockExamsProvider =
    FutureProvider.autoDispose<List<MockExamSummary>>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(mockExamRepositoryProvider).fetchMockExams();
});

final examHistoryProvider =
    FutureProvider.autoDispose<List<ExamHistoryItem>>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(mockExamRepositoryProvider).fetchExamHistory();
});

final mockInstructionsProvider = FutureProvider.autoDispose
    .family<MockExamInstructions, int>((ref, examId) async {
  return ref.read(mockExamRepositoryProvider).fetchInstructions(examId);
});

final mockPreflightProvider = FutureProvider.autoDispose
    .family<MockPreflight, int>((ref, attemptId) async {
  return ref.read(mockExamRepositoryProvider).fetchPreflight(attemptId);
});

final mockResultProvider = FutureProvider.autoDispose
    .family<MockAttemptResult, int>((ref, attemptId) async {
  return ref.read(mockExamRepositoryProvider).fetchResult(attemptId);
});

final examInsightProvider = FutureProvider.autoDispose
    .family<ExamAiInsight, int>((ref, attemptId) async {
  return ref.read(mockExamRepositoryProvider).fetchExamInsight(attemptId);
});

final mockReviewProvider = FutureProvider.autoDispose
    .family<MockAttemptReview, int>((ref, attemptId) async {
  return ref.read(mockExamRepositoryProvider).fetchReview(attemptId);
});
