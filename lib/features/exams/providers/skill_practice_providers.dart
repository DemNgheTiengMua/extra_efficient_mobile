import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../context/learner_context_provider.dart';
import '../data/skill_practice_repository.dart';
import '../models/skill_practice_models.dart';

final skillPracticeRepositoryProvider = Provider<SkillPracticeRepository>((ref) {
  return SkillPracticeRepository(ref.watch(dioProvider));
});

final speakingCatalogProvider =
    FutureProvider.autoDispose<List<SkillPracticeExamSummary>>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(skillPracticeRepositoryProvider).fetchCatalog('speaking');
});

final writingCatalogProvider =
    FutureProvider.autoDispose<List<SkillPracticeExamSummary>>((ref) async {
  ref.watch(certificateScopeVersionProvider);
  return ref.read(skillPracticeRepositoryProvider).fetchCatalog('writing');
});
