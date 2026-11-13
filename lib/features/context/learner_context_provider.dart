import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../auth/auth_provider.dart';
import 'learner_context_models.dart';

/// Incremented whenever the active Certificate is switched so all
/// certificate-scoped providers and tabs refresh cleanly.
class CertificateScopeVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final certificateScopeVersionProvider =
    NotifierProvider<CertificateScopeVersionNotifier, int>(
  CertificateScopeVersionNotifier.new,
);

/// Manages `GET /api/learner/context` and `PUT /api/learner/active-certificate`.
class LearnerContextNotifier extends AsyncNotifier<LearnerContext?> {
  @override
  Future<LearnerContext?> build() async {
    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated) {
      return null;
    }
    return _fetchContext();
  }

  Future<LearnerContext> _fetchContext() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get<Map<String, dynamic>>('/api/learner/context');
    final data = response.data ?? const <String, dynamic>{};
    return LearnerContext.fromJson(data);
  }

  Future<void> refreshContext() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchContext);
  }

  Future<void> switchActiveCertificate(String code) async {
    final dio = ref.read(dioProvider);
    await dio.put<void>(
      '/api/learner/active-certificate',
      data: {'code': code},
    );
    ref.read(certificateScopeVersionProvider.notifier).bump();
    await refreshContext();
  }
}

final learnerContextProvider =
    AsyncNotifierProvider<LearnerContextNotifier, LearnerContext?>(
  LearnerContextNotifier.new,
);
