import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../context/learner_context_provider.dart';
import '../data/placement_repository.dart';
import '../models/placement_models.dart';

final placementRepositoryProvider = Provider<PlacementRepository>((ref) {
  return PlacementRepository(ref.watch(dioProvider));
});

/// The catalogue is a read with an on-screen RETRY, so a failure should surface
/// at once rather than after Riverpod's ~38-second default retry ladder.
Duration? _noRetry(int retryCount, Object error) => null;

final placementCatalogProvider = FutureProvider.autoDispose<PlacementCatalog>((
  ref,
) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(placementRepositoryProvider).fetchCatalog();
}, retry: _noRetry);

final placementPreflightProvider =
    FutureProvider.autoDispose<PlacementPreflight>((ref) async {
      ref.watch(certificateScopeVersionProvider);
      return ref.read(placementRepositoryProvider).fetchPreflight();
    }, retry: _noRetry);
