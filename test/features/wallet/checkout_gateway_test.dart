import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/wallet/wallet_providers.dart';
import '../../helpers/fake_http_adapter.dart';

class _RecordingUrlLauncher implements UrlLauncherAdapter {
  final List<String> launchedUrls = [];

  @override
  Future<bool> launchExternalUrl(String url) async {
    launchedUrls.add(url);
    return true;
  }
}

void main() {
  testWidgets(
    'Checkout creates order, launches checkoutUrl, completes via Mock Gateway paid, and refreshes wallet',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      final urlLauncher = _RecordingUrlLauncher();

      var creditBalance = 13;
      var purchased = 20;
      var orderStatus = 'pending';
      var orderCreated = false;
      String? mockActionSent;

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/me') {
          return FakeHttpClientAdapter.jsonResponse({
            'userId': 2,
            'email': 'learner@demo.local',
            'fullName': 'Demo Learner',
            'role': 'learner',
            'emailVerified': true,
            'permissions': [],
            'held': [],
          });
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse({
            'active': {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'certificates': [
              {
                'code': 'TOEIC',
                'name': 'TOEIC Listening & Reading',
                'sectionNoun': 'Part',
              },
            ],
            'creditBalance': creditBalance,
            'examinedSkills': ['listening', 'reading'],
            'examDate': null,
          });
        }
        if (options.path == '/api/learner/wallet') {
          return FakeHttpClientAdapter.jsonResponse({
            'creditsPurchased': purchased,
            'creditsUsed': 7,
            'balance': creditBalance,
            'ledger': const [],
            'orders': orderCreated
                ? [
                    {
                      'orderCode': 'ORD-2001',
                      'packageId': 2,
                      'packageName': 'Pro 60',
                      'credits': 60,
                      'amountVnd': 499000,
                      'status': orderStatus,
                      'checkoutUrl': 'https://pay.payos.vn/web/ORD-2001',
                      'createdAt': '2026-11-13T09:00:00Z',
                    },
                  ]
                : const [],
          });
        }
        if (options.path == '/api/packages') {
          return FakeHttpClientAdapter.jsonResponse({
            'packages': [
              {
                'id': 2,
                'name': 'Pro 60',
                'credits': 60,
                'priceVnd': 499000,
                'isFeatured': true,
                'description': 'Best value for full certificate prep.',
              },
            ],
          });
        }
        if (options.path == '/api/checkout/preview') {
          return FakeHttpClientAdapter.jsonResponse({
            'packageId': 2,
            'packageName': 'Pro 60',
            'credits': 60,
            'amountVnd': 499000,
            'hasOpenOrder': false,
          });
        }
        if (options.path == '/api/checkout/orders' &&
            options.method == 'POST') {
          orderCreated = true;
          orderStatus = 'pending';
          return FakeHttpClientAdapter.jsonResponse({
            'orderCode': 'ORD-2001',
            'packageId': 2,
            'packageName': 'Pro 60',
            'credits': 60,
            'amountVnd': 499000,
            'status': 'pending',
            'checkoutUrl': 'https://pay.payos.vn/web/ORD-2001',
            'createdAt': '2026-11-13T09:00:00Z',
          });
        }
        if (options.path == '/api/mock-gateway/action' &&
            options.method == 'POST') {
          mockActionSent = body['action'] as String;
          if (mockActionSent == 'paid') {
            orderStatus = 'paid';
            purchased = 80;
            creditBalance = 73;
          }
          return FakeHttpClientAdapter.jsonResponse({
            'orderCode': 'ORD-2001',
            'packageId': 2,
            'packageName': 'Pro 60',
            'credits': 60,
            'amountVnd': 499000,
            'status': orderStatus,
          });
        }
        if (options.path == '/api/checkout/orders/ORD-2001/result') {
          return FakeHttpClientAdapter.jsonResponse({
            'orderCode': 'ORD-2001',
            'packageId': 2,
            'packageName': 'Pro 60',
            'credits': 60,
            'amountVnd': 499000,
            'status': orderStatus,
            'checkoutUrl': 'https://pay.payos.vn/web/ORD-2001',
          });
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(tokenStorage),
            httpClientAdapterProvider.overrideWithValue(adapter),
            audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
            urlLauncherAdapterProvider.overrideWithValue(urlLauncher),
          ],
          child: const ExtraEfficientApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('WALLET'));
      await tester.pumpAndSettle();

      // Tap BUY on Pro 60
      await tester.tap(find.byKey(const Key('buy-package-2')));
      await tester.pumpAndSettle();

      // Checkout preview shown
      expect(find.text('CHECKOUT PREVIEW'), findsOneWidget);
      expect(find.text('Pro 60'), findsWidgets);

      // Create order
      await tester.tap(find.byKey(const Key('create-order-button')));
      await tester.pumpAndSettle();

      // Pending order state
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('ORD-2001'), findsOneWidget);

      // Launch external payOS URL
      await tester.tap(find.byKey(const Key('open-gateway-url-button')));
      await tester.pumpAndSettle();
      expect(urlLauncher.launchedUrls, ['https://pay.payos.vn/web/ORD-2001']);

      // Simulate Paid via Mock Gateway
      await tester.ensureVisible(
        find.byKey(const Key('mock-gateway-paid-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mock-gateway-paid-button')));
      await tester.pumpAndSettle();

      expect(mockActionSent, 'paid');
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('73 CREDITS'), findsOneWidget);
    },
  );

  testWidgets(
    'Single-open-order guard blocks new order when reconciling order exists and renders failed/expired states',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      var orderStatus = 'reconciling';

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/me') {
          return FakeHttpClientAdapter.jsonResponse({
            'userId': 2,
            'email': 'learner@demo.local',
            'fullName': 'Demo Learner',
            'role': 'learner',
            'emailVerified': true,
            'permissions': [],
            'held': [],
          });
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse({
            'active': {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'certificates': [
              {
                'code': 'TOEIC',
                'name': 'TOEIC Listening & Reading',
                'sectionNoun': 'Part',
              },
            ],
            'creditBalance': 13,
            'examinedSkills': ['listening', 'reading'],
            'examDate': null,
          });
        }
        if (options.path == '/api/learner/wallet') {
          return FakeHttpClientAdapter.jsonResponse({
            'creditsPurchased': 20,
            'creditsUsed': 7,
            'balance': 13,
            'ledger': const [],
            'orders': [
              {
                'orderCode': 'ORD-OPEN-1',
                'packageId': 2,
                'packageName': 'Pro 60',
                'credits': 60,
                'amountVnd': 499000,
                'status': orderStatus,
                'createdAt': '2026-11-13T09:00:00Z',
              },
            ],
          });
        }
        if (options.path == '/api/packages') {
          return FakeHttpClientAdapter.jsonResponse({
            'packages': [
              {
                'id': 2,
                'name': 'Pro 60',
                'credits': 60,
                'priceVnd': 499000,
                'isFeatured': true,
                'description': 'Best value',
              },
            ],
          });
        }
        if (options.path == '/api/checkout/orders/ORD-OPEN-1/result') {
          return FakeHttpClientAdapter.jsonResponse({
            'orderCode': 'ORD-OPEN-1',
            'packageId': 2,
            'packageName': 'Pro 60',
            'credits': 60,
            'amountVnd': 499000,
            'status': orderStatus,
            'errorCode': orderStatus == 'failed' ? 'GATEWAY_DECLINED' : null,
          });
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(tokenStorage),
            httpClientAdapterProvider.overrideWithValue(adapter),
            audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
          ],
          child: const ExtraEfficientApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('WALLET'));
      await tester.pumpAndSettle();

      // Single-open-order guard banner & disabled/blocked new order
      expect(find.textContaining('Do not pay again'), findsOneWidget);
      expect(find.byKey(const Key('view-open-order-button')), findsOneWidget);

      // Open the reconciling order
      await tester.tap(find.byKey(const Key('view-open-order-button')));
      await tester.pumpAndSettle();
      expect(find.text('RECONCILING'), findsWidgets);

      // Transition to failed and check status
      orderStatus = 'failed';
      await tester.tap(find.byKey(const Key('check-order-status-button')));
      await tester.pumpAndSettle();
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.textContaining('GATEWAY_DECLINED'), findsOneWidget);

      // Transition to expired and check status
      orderStatus = 'expired';
      await tester.tap(find.byKey(const Key('check-order-status-button')));
      await tester.pumpAndSettle();
      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.textContaining('15-minute'), findsOneWidget);
    },
  );
}
