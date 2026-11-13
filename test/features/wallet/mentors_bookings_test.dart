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
    'Mentors & Bookings supports human slot booking and AI immediate booking',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      var creditBalance = 13;
      final recordedBookPayloads = <String, Map<String, dynamic>>{};

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
            'creditsPurchased': 20,
            'creditsUsed': 20 - creditBalance,
            'balance': creditBalance,
            'ledger': const [],
            'orders': const [],
          });
        }
        if (options.path == '/api/packages') {
          return FakeHttpClientAdapter.jsonResponse({'packages': const []});
        }
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse({
            'mentors': [
              {
                'id': 10,
                'name': 'Minh Tran',
                'headline': 'TOEIC 985 · Reading & Listening Coach',
                'expertise': 'reading,listening',
                'sessionLengthMinutes': 45,
                'priceCredits': 3,
                'isAi': false,
                'averageRating': 4.9,
              },
              {
                'id': 20,
                'name': 'AI Speaking Coach',
                'headline': 'Instant AI feedback session',
                'expertise': 'speaking',
                'sessionLengthMinutes': 20,
                'priceCredits': 1,
                'isAi': true,
                'averageRating': 4.7,
              },
            ],
          });
        }
        if (options.path == '/api/mentors/10') {
          return FakeHttpClientAdapter.jsonResponse({
            'id': 10,
            'name': 'Minh Tran',
            'headline': 'TOEIC 985 · Reading & Listening Coach',
            'expertise': 'reading,listening',
            'sessionLengthMinutes': 45,
            'priceCredits': 3,
            'isAi': false,
            'averageRating': 4.9,
            'slots': [
              {
                'id': 501,
                'startsAt': '2026-11-15T10:00:00Z',
                'endsAt': '2026-11-15T10:45:00Z',
                'isAvailable': true,
              },
            ],
          });
        }
        if (options.path == '/api/mentors/20') {
          return FakeHttpClientAdapter.jsonResponse({
            'id': 20,
            'name': 'AI Speaking Coach',
            'headline': 'Instant AI feedback session',
            'expertise': 'speaking',
            'sessionLengthMinutes': 20,
            'priceCredits': 1,
            'isAi': true,
            'averageRating': 4.7,
            'slots': const [],
          });
        }
        if (options.path == '/api/mentors/10/book' &&
            options.method == 'POST') {
          recordedBookPayloads['human'] = Map<String, dynamic>.from(body as Map);
          creditBalance -= 3;
          return FakeHttpClientAdapter.jsonResponse({
            'id': 901,
            'mentorId': 10,
            'mentorName': 'Minh Tran',
            'status': 'confirmed',
            'focusArea': body['focusArea'],
            'meetLink': 'https://meet.google.com/abc-defg-hij',
            'priceCredits': 3,
          });
        }
        if (options.path == '/api/mentors/20/book' &&
            options.method == 'POST') {
          recordedBookPayloads['ai'] = Map<String, dynamic>.from(body as Map);
          creditBalance -= 1;
          return FakeHttpClientAdapter.jsonResponse({
            'id': 902,
            'mentorId': 20,
            'mentorName': 'AI Speaking Coach',
            'isAi': true,
            'status': 'confirmed',
            'focusArea': body['focusArea'],
            'priceCredits': 1,
          });
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse({'bookings': const []});
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

      await tester.tap(find.byKey(const Key('wallet-subtab-mentors')));
      await tester.pumpAndSettle();

      expect(find.text('Minh Tran'), findsOneWidget);
      expect(find.text('AI Speaking Coach'), findsOneWidget);

      // Book human mentor with slot + focus area
      await tester.tap(find.byKey(const Key('open-mentor-10')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mentor-slot-501')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('booking-focus-area-field')),
        'Part 7 inference',
      );
      await tester.ensureVisible(
        find.byKey(const Key('confirm-booking-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking-button')));
      await tester.pumpAndSettle();

      expect(recordedBookPayloads['human']?['slotId'], 501);
      expect(recordedBookPayloads['human']?['focusArea'], 'Part 7 inference');
      expect(find.text('10 CREDITS'), findsOneWidget);

      // Book AI mentor immediately without a slot
      await tester.ensureVisible(find.byKey(const Key('open-mentor-20')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-mentor-20')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('confirm-booking-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking-button')));
      await tester.pumpAndSettle();

      expect(recordedBookPayloads['ai']?['slotId'], isNull);
      expect(find.text('9 CREDITS'), findsOneWidget);
    },
  );

  testWidgets(
    'Bookings display Google Meet link, support cancellation refund, and submit star rating/review',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      final urlLauncher = _RecordingUrlLauncher();
      var creditBalance = 10;
      var cancelled = false;
      Map<String, dynamic>? ratingPayload;

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
            'creditsPurchased': 20,
            'creditsUsed': 20 - creditBalance,
            'balance': creditBalance,
            'ledger': const [],
            'orders': const [],
          });
        }
        if (options.path == '/api/packages') {
          return FakeHttpClientAdapter.jsonResponse({'packages': const []});
        }
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse({'mentors': const []});
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse({
            'bookings': [
              {
                'id': 901,
                'mentorId': 10,
                'mentorName': 'Minh Tran',
                'status': cancelled ? 'cancelled' : 'confirmed',
                'focusArea': 'Part 7 inference',
                'meetLink': 'https://meet.google.com/abc-defg-hij',
                'priceCredits': 3,
              },
              {
                'id': 902,
                'mentorId': 20,
                'mentorName': 'AI Speaking Coach',
                'isAi': true,
                'status': 'completed',
                'focusArea': 'Fluency',
                'priceCredits': 1,
                'rating': ratingPayload?['rating'],
                'reviewText': ratingPayload?['text'],
              },
            ],
          });
        }
        if (options.path == '/api/mentors/bookings/901/cancel' &&
            options.method == 'POST') {
          cancelled = true;
          creditBalance += 3;
          return FakeHttpClientAdapter.jsonResponse({'status': 'cancelled'});
        }
        if (options.path == '/api/mentors/bookings/902/rate' &&
            options.method == 'POST') {
          ratingPayload = Map<String, dynamic>.from(body as Map);
          return FakeHttpClientAdapter.jsonResponse({'ok': true});
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

      await tester.tap(find.byKey(const Key('wallet-subtab-mentors')));
      await tester.pumpAndSettle();

      // Google Meet link visible and launchable
      await tester.ensureVisible(
        find.byKey(const Key('join-meet-button-901')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('join-meet-button-901')));
      await tester.pumpAndSettle();
      expect(
        urlLauncher.launchedUrls,
        ['https://meet.google.com/abc-defg-hij'],
      );

      // Cancel booking -> refunds 3 credits
      await tester.ensureVisible(
        find.byKey(const Key('cancel-booking-button-901')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-booking-button-901')));
      await tester.pumpAndSettle();
      expect(find.text('13 CREDITS'), findsOneWidget);

      // Rate completed booking
      await tester.ensureVisible(
        find.byKey(const Key('rate-booking-button-902')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate-booking-button-902')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rate-star-5')));
      await tester.enterText(
        find.byKey(const Key('rate-review-field')),
        'Clear feedback',
      );
      await tester.tap(find.byKey(const Key('submit-rating-button')));
      await tester.pumpAndSettle();

      expect(ratingPayload?['rating'], 5);
      expect(ratingPayload?['text'], 'Clear feedback');
    },
  );
}
