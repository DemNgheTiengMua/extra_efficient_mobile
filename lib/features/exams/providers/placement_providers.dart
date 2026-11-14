import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/provider_retry.dart';
import '../../context/learner_context_provider.dart';
import '../data/placement_repository.dart';
import '../models/placement_models.dart';

final placementRepositoryProvider = Provider<PlacementRepository>((ref) {
  return PlacementRepository(ref.watch(dioProvider));
});

final placementCatalogProvider = FutureProvider.autoDispose<PlacementCatalog>((
  ref,
) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(placementRepositoryProvider).fetchCatalog();
}, retry: noProviderRetry);

final placementPreflightProvider =
    FutureProvider.autoDispose<PlacementPreflight>((ref) async {
      ref.watch(certificateScopeVersionProvider);
      return ref.read(placementRepositoryProvider).fetchPreflight();
    }, retry: noProviderRetry);
