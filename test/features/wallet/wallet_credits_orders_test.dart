import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  testWidgets(
    'WALLET Credits & Orders tab displays derived balance, append-only ledger, past orders, and featured package',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');

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
            'ledger': [
              {
                'id': 101,
                'delta': 20,
                'reason': 'package_purchase',
                'provenance': 'order:ORD-1001',
                'createdAt': '2026-11-10T08:00:00Z',
              },
              {
                'id': 102,
                'delta': -5,
                'reason': 'mock_exam_start',
                'provenance': 'attempt:55',
                'createdAt': '2026-11-11T09:30:00Z',
              },
              {
                'id': 103,
                'delta': -2,
                'reason': 'mentor_booking',
                'provenance': 'booking:12',
                'createdAt': '2026-11-12T14:00:00Z',
              },
            ],
            'orders': [
              {
                'orderCode': 'ORD-1001',
                'packageId': 1,
                'packageName': 'Starter 20',
                'credits': 20,
                'amountVnd': 199000,
                'status': 'paid',
                'createdAt': '2026-11-10T08:00:00Z',
              },
            ],
          });
        }
        if (options.path == '/api/packages') {
          return FakeHttpClientAdapter.jsonResponse({
            'packages': [
              {
                'id': 1,
                'name': 'Starter 20',
                'credits': 20,
                'priceVnd': 199000,
                'isFeatured': false,
                'description': '20 credits for mock exams and AI grading.',
              },
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

      // Derived balance: purchased - used = balance
      expect(find.text('20'), findsWidgets);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('13'), findsWidgets);

      // Credit packages + featured highlight
      expect(find.text('Starter 20'), findsWidgets);
      expect(find.text('Pro 60'), findsOneWidget);
      expect(find.text('FEATURED'), findsOneWidget);

      // Scroll to Append-only ledger rows
      await tester.scrollUntilVisible(find.text('+20'), 200);
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);
      expect(find.textContaining('package_purchase'), findsOneWidget);
      expect(find.textContaining('mock_exam_start'), findsOneWidget);
      expect(find.textContaining('mentor_booking'), findsOneWidget);

      // Scroll to Past orders
      await tester.scrollUntilVisible(find.text('ORD-1001'), 200);
      expect(find.text('ORD-1001'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
    },
  );
}
