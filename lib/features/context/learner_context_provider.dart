import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/provider_retry.dart';
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

  /// Re-reads the context without ever flashing a loading state.
  ///
  /// Used when the server may have changed the balance behind the learner's
  /// back - an administrator granting a make-good credit, a refund settling -
  /// so the header pill and every credit figure update in place instead of
  /// waiting for a sign-out.
  Future<void> refreshContextQuietly() async {
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    try {
      final fresh = await _fetchContext();
      state = AsyncData(fresh);
    } catch (_) {
      // A failed background refresh must not replace good data with an error;
      // the displayed balance simply stays as it was.
    }
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
  retry: noProviderRetry,
);
