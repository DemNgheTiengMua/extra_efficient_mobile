import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/platform/external_url_launcher.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../contract/fixture_loader.dart';
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

/// Serves the recorded wallet, packages and checkout fixtures, and lets one
/// test swap the checkout preview or fail the order call.
FakeHttpClientAdapter _adapter({
  Object? preview,
  Object? orderResponse,
  Object? orderStatus = 200,
  Object? result,
}) {
  return FakeHttpClientAdapter((options, body) async {
    if (options.path == '/api/auth/me') {
      return FakeHttpClientAdapter.jsonResponse(_user());
    }
    if (options.path == '/api/learner/context') {
      return FakeHttpClientAdapter.jsonResponse(_context());
    }
    if (options.path == '/api/learner/wallet') {
      return FakeHttpClientAdapter.jsonResponse(loadFixture('wallet'));
    }
    if (options.path == '/api/packages') {
      return FakeHttpClientAdapter.jsonResponse(loadFixture('credit_packages'));
    }
    if (options.path == '/api/checkout/preview') {
      return FakeHttpClientAdapter.jsonResponse(
        preview ?? loadFixture('checkout_preview'),
      );
    }
    if (options.path == '/api/checkout/orders' && options.method == 'POST') {
      return FakeHttpClientAdapter.jsonResponse(
        orderResponse ?? loadFixture('checkout_create_order'),
        statusCode: orderStatus as int,
      );
    }
    if (options.path.endsWith('/result')) {
      return FakeHttpClientAdapter.jsonResponse(
        result ?? loadFixture('payment_result_failed'),
      );
    }
    return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  FakeHttpClientAdapter adapter, {
  UrlLauncherAdapter? launcher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage(initialToken: 'valid-jwt'),
        ),
        httpClientAdapterProvider.overrideWithValue(adapter),
        audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        if (launcher != null)
          urlLauncherAdapterProvider.overrideWithValue(launcher),
      ],
      child: const ExtraEfficientApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('WALLET'));
  await tester.pumpAndSettle();
}

Future<void> _buy(WidgetTester tester, int packageId) async {
  final button = find.byKey(Key('buy-package-$packageId'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('checkout quotes the package price recorded from the backend', (
    tester,
  ) async {
    await _pumpApp(tester, _adapter());
    await _buy(tester, 2);

    expect(find.text('CHECKOUT PREVIEW'), findsOneWidget);
    // The backend's `price` for package 2; never 0 ₫.
    expect(find.text('100,000 ₫'), findsOneWidget);
    expect(find.text('0 ₫'), findsNothing);
  });

  testWidgets('an open order blocks checkout and surfaces that order', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      _adapter(preview: loadFixture('checkout_preview_open_order')),
    );
    await _buy(tester, 1);

    // Blocked, no way to create a second order, and the existing one is named.
    expect(find.byKey(const Key('create-order-button')), findsNothing);
    expect(find.textContaining('DH-20261113-0103'), findsOneWidget);

    await _tapAndSettle(tester, 'view-open-order-button');

    expect(find.text('ORDER DETAILS'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets('a failed order shows the gateway error code', (tester) async {
    await _pumpApp(tester, _adapter());
    await _buy(tester, 1);
    await _tapAndSettle(tester, 'create-order-button');

    expect(find.text('PENDING'), findsOneWidget);
    await _tapAndSettle(tester, 'check-order-status-button');

    expect(find.text('FAILED'), findsOneWidget);
    expect(find.textContaining('MOCK_DECLINED'), findsOneWidget);
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
        return FakeHttpClientAdapter.jsonResponse(loadFixture('wallet'));
      }
      if (options.path == '/api/packages') {
        return FakeHttpClientAdapter.jsonResponse(
          loadFixture('credit_packages'),
        );
      }
      if (options.path == '/api/checkout/preview') {
        return FakeHttpClientAdapter.jsonResponse(
          loadFixture('checkout_preview'),
        );
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

    await _pumpApp(tester, adapter);
    await _buy(tester, 2);
    await _tapAndSettle(tester, 'create-order-button');

    // The failure is reported, not swallowed, and the control is still usable.
    expect(find.text('Checkout error'), findsOneWidget);
    expect(find.text('You already have an open order.'), findsOneWidget);
    expect(find.byKey(const Key('create-order-button')), findsOneWidget);

    await _tapAndSettle(tester, 'create-order-button');
    expect(attempts, 2);
  });

  testWidgets('OPEN PAYMENT GATEWAY launches the checkout url', (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpApp(tester, _adapter(), launcher: launcher);

    await _buy(tester, 1);
    await _tapAndSettle(tester, 'create-order-button');
    await _tapAndSettle(tester, 'open-gateway-url-button');

    // The mock gateway's checkout url is root-relative; the launcher resolves it.
    expect(launcher.launchedUrls, [
      '/checkout/mock-gateway?orderCode=DH-20261113-0103',
    ]);
    expect(find.text('Could not open link'), findsNothing);
  });

  testWidgets('a gateway that cannot open reports a message', (tester) async {
    final launcher = _RecordingLauncher(result: false);
    await _pumpApp(tester, _adapter(), launcher: launcher);

    await _buy(tester, 1);
    await _tapAndSettle(tester, 'create-order-button');
    await _tapAndSettle(tester, 'open-gateway-url-button');

    expect(find.text('Could not open link'), findsOneWidget);
    expect(
      find.textContaining('Copy this link into a browser'),
      findsOneWidget,
    );
  });
}
