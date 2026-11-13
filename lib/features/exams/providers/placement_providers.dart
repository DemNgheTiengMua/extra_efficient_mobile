import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../context/learner_context_provider.dart';
import '../data/placement_repository.dart';
import '../models/placement_models.dart';

final placementRepositoryProvider = Provider<PlacementRepository>((ref) {
  return PlacementRepository(ref.watch(dioProvider));
});

final placementOverviewProvider =
    FutureProvider.autoDispose<PlacementOverview>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(placementRepositoryProvider).fetchOverview();
});

final placementPreflightProvider =
    FutureProvider.autoDispose<PlacementPreflight>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(placementRepositoryProvider).fetchPreflight();
});
