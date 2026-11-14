import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/auth/auth_models.dart';
import 'package:extra_efficient_mobile/features/auth/auth_provider.dart';
import 'package:extra_efficient_mobile/features/context/learner_context_models.dart';
import 'package:extra_efficient_mobile/features/context/learner_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

/// The credit balance can change outside the app: an administrator grants a
/// make-good credit, a refund settles, a payment completes on another device.
/// The learner must see it without signing out, so the context is re-read on
/// resume and on opening WALLET.
void main() {
  Map<String, dynamic> contextPayload(int balance) => {
    'active': {
      'code': 'TOEIC',
      'name': 'TOEIC Listening & Reading',
      'sectionNoun': 'Part',
    },
    'certificates': <Map<String, dynamic>>[],
    'creditBalance': balance,
    'examinedSkills': <String>['listening', 'reading'],
    'examDate': null,
  };

  ProviderContainer buildContainer(FakeHttpClientAdapter adapter) {
    final container = ProviderContainer(
      overrides: [
        httpClientAdapterProvider.overrideWithValue(adapter),
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage(initialToken: 'test-token'),
        ),
        // Signed in, so the context provider does not short-circuit to null.
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a quiet refresh picks up a balance changed behind the app', () async {
    var balance = 11;
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(contextPayload(balance));
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    final container = buildContainer(adapter);

    final initial = await container.read(learnerContextProvider.future);
    expect(initial?.creditBalance, 11);

    // An administrator grants a credit while the app is open.
    balance = 12;

    await container
        .read(learnerContextProvider.notifier)
        .refreshContextQuietly();

    expect(
      container.read(learnerContextProvider).value?.creditBalance,
      12,
      reason: 'the granted credit must appear without a sign-out',
    );
  });

  test('a quiet refresh never replaces good data with an error', () async {
    var failing = false;
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/context') {
        return failing
            ? FakeHttpClientAdapter.jsonResponse(
                {'title': 'boom'},
                statusCode: 500,
              )
            : FakeHttpClientAdapter.jsonResponse(contextPayload(7));
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    final container = buildContainer(adapter);
    await container.read(learnerContextProvider.future);
    expect(container.read(learnerContextProvider).value?.creditBalance, 7);

    failing = true;
    await container
        .read(learnerContextProvider.notifier)
        .refreshContextQuietly();

    final state = container.read(learnerContextProvider);
    expect(state.hasError, isFalse);
    expect(
      state.value?.creditBalance,
      7,
      reason: 'a failed quiet refresh must not wipe the displayed balance',
    );
  });

  test('LearnerContext parses the balance the backend actually sends', () {
    final parsed = LearnerContext.fromJson(contextPayload(13));
    expect(parsed.creditBalance, 13);
    expect(parsed.active.code, 'TOEIC');
  });
}

/// A permanently signed-in auth state, so the context provider runs.
class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.authenticated(
    AuthUser(
      userId: 2,
      email: 'learner@demo.local',
      fullName: 'Demo Learner',
      role: 'learner',
      emailVerified: true,
    ),
  );
}
