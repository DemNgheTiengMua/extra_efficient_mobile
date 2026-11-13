import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../auth/auth_provider.dart';
import '../context/learner_context_provider.dart';
import 'mentor_models.dart';
import 'mentor_repository.dart';

final mentorRepositoryProvider = Provider<MentorRepository>((ref) {
  return MentorRepository(ref.watch(dioProvider));
});

/// The directory. Auto-retry is disabled so a failing load reaches the screen's
/// error branch immediately instead of spinning for ~38 s.
final mentorsListProvider = FutureProvider<List<MentorProfile>>(
  (ref) async {
    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated) {
      return const [];
    }
    ref.watch(certificateScopeVersionProvider);
    final certCode = ref.watch(learnerContextProvider).value?.active.code;
    return ref.read(mentorRepositoryProvider).getMentors(certCode: certCode);
  },
  retry: (_, _) => null,
);

class MentorBookingsNotifier extends AsyncNotifier<List<MentorBooking>> {
  @override
  Future<List<MentorBooking>> build() async {
    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated) {
      return const [];
    }
    return ref.read(mentorRepositoryProvider).getBookings();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(mentorRepositoryProvider).getBookings(),
    );
  }
}

final mentorBookingsProvider =
    AsyncNotifierProvider<MentorBookingsNotifier, List<MentorBooking>>(
  MentorBookingsNotifier.new,
  retry: (_, _) => null,
);
