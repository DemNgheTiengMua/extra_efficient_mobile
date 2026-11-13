import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/provider_retry.dart';
import '../data/mock_exam_repository.dart';
import '../data/placement_repository.dart';
import '../models/preflight_models.dart';
import 'mock_exam_providers.dart';
import 'placement_providers.dart';

/// Which door a sitting is reached through. The two surfaces differ only in
/// their reading route and where a finished sitting belongs.
enum SittingKind { placement, attempt }

/// A sitting addressed the way its door addresses it.
///
/// A placement is addressed by `placementId`; a mock attempt by `attemptId`.
class SittingRef {
  const SittingRef({required this.kind, required this.sittingId});

  final SittingKind kind;
  final int sittingId;

  @override
  bool operator ==(Object other) =>
      other is SittingRef &&
      other.kind == kind &&
      other.sittingId == sittingId;

  @override
  int get hashCode => Object.hash(kind, sittingId);
}

/// The one gate both doors use: read the status, then verify it.
class ExamRoomGate {
  const ExamRoomGate({
    required this.placementRepository,
    required this.attemptRepository,
  });

  final PlacementRepository placementRepository;
  final MockExamRepository attemptRepository;

  Future<PreflightStatus> readStatus(SittingRef ref) =>
      ref.kind == SittingKind.placement
          ? placementRepository.fetchPreflightStatus(ref.sittingId)
          : attemptRepository.fetchPreflightStatus(ref.sittingId);

  /// Verifies the device gate.
  ///
  /// The [attemptId] is the one the status payload reported. A placement has no
  /// verify route of its own - it adapts an attempt, and the attempt's route is
  /// what marks it verified - so the kind is not needed here.
  Future<PreflightStatus> verifyPreflight({required int attemptId}) =>
      attemptRepository.verifyPreflight(attemptId);
}

final examRoomGateProvider = Provider<ExamRoomGate>((ref) {
  return ExamRoomGate(
    placementRepository: ref.watch(placementRepositoryProvider),
    attemptRepository: ref.watch(mockExamRepositoryProvider),
  );
});

final preflightStatusProvider = FutureProvider.autoDispose
    .family<PreflightStatus, SittingRef>((ref, sitting) {
      return ref.watch(examRoomGateProvider).readStatus(sitting);
    }, retry: noProviderRetry);
