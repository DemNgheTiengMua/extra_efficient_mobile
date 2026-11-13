import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/platform/external_url_launcher.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../fixtures/wallet_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';

class _RecordingLauncher implements UrlLauncherAdapter {
  _RecordingLauncher({this.result = true});

  final bool result;
  final List<String> launchedUrls = [];

  @override
  Future<bool> launchExternalUrl(String url) async {
    launchedUrls.add(url);
    return result;
  }
}

Map<String, dynamic> _user() => {
  'userId': 2,
  'email': 'learner@demo.local',
  'fullName': 'Demo Learner',
  'role': 'learner',
  'emailVerified': true,
  'permissions': [],
  'held': [],
};

Map<String, dynamic> _context() => {
  'active': {'code': 'TOEIC', 'name': 'TOEIC', 'sectionNoun': 'Part'},
  'certificates': [
    {'code': 'TOEIC', 'name': 'TOEIC', 'sectionNoun': 'Part'},
  ],
  'creditBalance': 11,
  'examinedSkills': ['listening', 'reading'],
  'examDate': null,
};

void main() {
  testWidgets('checkout quotes the package price recorded from the backend', (
    tester,
  ) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(_user());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(_context());
      }
      if (options.path == '/api/learner/wallet') {
        return FakeHttpClientAdapter.jsonResponse(walletPayload);
      }
      if (options.path == '/api/packages') {
        return FakeHttpClientAdapter.jsonResponse(packagesPayload);
      }
      if (options.path == '/api/checkout/preview') {
        return FakeHttpClientAdapter.jsonResponse(checkoutPreviewPayload);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('buy-package-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-package-2')));
    await tester.pumpAndSettle();

    expect(find.text('CHECKOUT PREVIEW'), findsOneWidget);
    // The backend's `price` for package 2; never 0 ₫.
    expect(find.text('100,000 ₫'), findsOneWidget);
    expect(find.text('0 ₫'), findsNothing);
  });

  testWidgets('an open order blocks checkout and surfaces that order', (
    tester,
  ) async {
    // The wallet snapshot can be stale, so the preview is the authority here.
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(_user());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(_context());
      }
      if (options.path == '/api/learner/wallet') {
        return FakeHttpClientAdapter.jsonResponse({
          ...walletPayload,
          'balance': 0,
          'creditsPurchased': 0,
          'creditsUsed': 0,
          'orders': const [],
        });
      }
      if (options.path == '/api/packages') {
        return FakeHttpClientAdapter.jsonResponse(packagesPayload);
      }
      if (options.path == '/api/checkout/preview') {
        return FakeHttpClientAdapter.jsonResponse(
          checkoutPreviewOpenOrderPayload,
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();

    // Blocked, no way to create a second order, and the existing one is named.
    expect(find.byKey(const Key('create-order-button')), findsNothing);
    expect(find.textContaining('DH-20261113-0101'), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-open-order-button')));
    await tester.pumpAndSettle();

    expect(find.text('ORDER DETAILS'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets('a failed order shows the gateway error code', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(_user());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(_context());
      }
      if (options.path == '/api/learner/wallet') {
        return FakeHttpClientAdapter.jsonResponse(walletPayload);
      }
      if (options.path == '/api/packages') {
        return FakeHttpClientAdapter.jsonResponse(packagesPayload);
      }
      if (options.path == '/api/checkout/preview') {
        return FakeHttpClientAdapter.jsonResponse(checkoutPreviewPayload);
      }
      if (options.path == '/api/checkout/orders' && options.method == 'POST') {
        return FakeHttpClientAdapter.jsonResponse(createdOrderPayload);
      }
      if (options.path == '/api/checkout/orders/DH-20261113-0101/result') {
        return FakeHttpClientAdapter.jsonResponse(
          paymentResultPayload(
            status: 'failed',
            gatewayErrorCode: 'PAYOS_TIMEOUT',
          ),
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-order-button')));
    await tester.pumpAndSettle();

    expect(find.text('PENDING'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('check-order-status-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-order-status-button')));
    await tester.pumpAndSettle();

    expect(find.text('FAILED'), findsOneWidget);
    expect(find.textContaining('PAYOS_TIMEOUT'), findsOneWidget);
  });

  testWidgets('a failed order creation reports the backend code and stays usable', (
    tester,
  ) async {
    var attempts = 0;
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(_user());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(_context());
      }
      if (options.path == '/api/learner/wallet') {
        return FakeHttpClientAdapter.jsonResponse(walletPayload);
      }
      if (options.path == '/api/packages') {
        return FakeHttpClientAdapter.jsonResponse(packagesPayload);
      }
      if (options.path == '/api/checkout/preview') {
        return FakeHttpClientAdapter.jsonResponse(checkoutPreviewPayload);
      }
      if (options.path == '/api/checkout/orders' && options.method == 'POST') {
        attempts++;
        return FakeHttpClientAdapter.jsonResponse({
          'code': 'order_already_open',
          'title': 'You already have an open order.',
          'status': 409,
        }, statusCode: 409);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('buy-package-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-package-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-order-button')));
    await tester.pumpAndSettle();

    // The failure is reported, not swallowed, and the control is still usable.
    expect(find.text('Checkout error'), findsOneWidget);
    expect(find.text('You already have an open order.'), findsOneWidget);
    expect(find.byKey(const Key('create-order-button')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('create-order-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-order-button')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('OPEN PAYMENT GATEWAY launches the checkout url', (tester) async {
    final launcher = _RecordingLauncher();

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(_user());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(_context());
      }
      if (options.path == '/api/learner/wallet') {
        return FakeHttpClientAdapter.jsonResponse(walletPayload);
      }
      if (options.path == '/api/packages') {
        return FakeHttpClientAdapter.jsonResponse(packagesPayload);
      }
      if (options.path == '/api/checkout/preview') {
        return FakeHttpClientAdapter.jsonResponse(checkoutPreviewPayload);
      }
      if (options.path == '/api/checkout/orders' && options.method == 'POST') {
        return FakeHttpClientAdapter.jsonResponse(createdOrderPayload);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
          urlLauncherAdapterProvider.overrideWithValue(launcher),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-order-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open-gateway-url-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-gateway-url-button')));
    await tester.pumpAndSettle();

    expect(launcher.launchedUrls, [
      '/checkout/mock-gateway?orderCode=DH-20261113-0101',
    ]);
    expect(find.textContaining('Could not open the payment gateway'), findsNothing);
  });

  testWidgets('a gateway that cannot open reports a message', (tester) async {
    final launcher = _RecordingLauncher(result: false);

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse(_user());
      }
      if (options.path == '/api/learner/context') {
        return FakeHttpClientAdapter.jsonResponse(_context());
      }
      if (options.path == '/api/learner/wallet') {
        return FakeHttpClientAdapter.jsonResponse(walletPayload);
      }
      if (options.path == '/api/packages') {
        return FakeHttpClientAdapter.jsonResponse(packagesPayload);
      }
      if (options.path == '/api/checkout/preview') {
        return FakeHttpClientAdapter.jsonResponse(checkoutPreviewPayload);
      }
      if (options.path == '/api/checkout/orders' && options.method == 'POST') {
        return FakeHttpClientAdapter.jsonResponse(createdOrderPayload);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(initialToken: 'valid-jwt'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
          urlLauncherAdapterProvider.overrideWithValue(launcher),
        ],
        child: const ExtraEfficientApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-package-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-order-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open-gateway-url-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-gateway-url-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open the payment gateway'), findsOneWidget);
  });
}




