import 'package:dio/dio.dart';
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

Map<String, dynamic> _humanSummary() => {
      'mentorId': 1,
      'userId': 4,
      'displayName': 'Dr. Trần Minh Khoa',
      'bio': '10 years teaching TOEIC.',
      'certId': 1,
      'certCode': 'TOEIC',
      'certName': 'TOEIC Listening & Reading',
      'skillId': 1,
      'skillCode': 'LIST',
      'skillName': 'Listening',
      'modality': 'listening',
      'type': 'human',
      'pricePerSlot': 200000.00,
      'priceCredits': 3,
      'headline': 'Listening strategies and accent training.',
      'expertise': 'Listening strategies, pronunciation',
      'sessionMinutes': 60,
      'isActive': true,
      'avgRating': 5.000000,
      'reviewCount': 1,
    };

Map<String, dynamic> _aiSummary() => {
      'mentorId': 2,
      'userId': null,
      'displayName': 'AI Mentor — TOEIC Coach',
      'bio': 'AI-powered speaking practice.',
      'certId': 1,
      'certCode': 'TOEIC',
      'certName': 'TOEIC Listening & Reading',
      'skillId': null,
      'skillCode': null,
      'skillName': null,
      'modality': null,
      'type': 'ai',
      'pricePerSlot': 0.00,
      'priceCredits': 1,
      'headline': 'AI-powered speaking practice.',
      'expertise': 'Instant speaking feedback',
      'sessionMinutes': 60,
      'isActive': true,
      'avgRating': null,
      'reviewCount': 0,
    };

Map<String, dynamic> _slot(int id, String start, String end) => {
      'slotId': id,
      'mentorId': 1,
      'startAt': start,
      'endAt': end,
      'status': 'open',
    };

/// Wraps a mentor-route handler with the auth/context/wallet/packages routes
/// the WALLET tab needs, so each test states only the routes it is about.
FakeHttpClientAdapter _adapter(
  Future<ResponseBody?> Function(RequestOptions options, dynamic body)
      mentorRoutes, {
  int Function()? creditBalance,
}) {
  return FakeHttpClientAdapter((options, body) async {
    final balance = creditBalance?.call() ?? 12;
    final routed = await mentorRoutes(options, body);
    if (routed != null) return routed;
    if (options.path == '/api/auth/me') {
      return FakeHttpClientAdapter.jsonResponse({
        'userId': 2,
        'email': 'learner@demo.local',
        'fullName': 'Demo Learner',
        'role': 'learner',
        'emailVerified': true,
        'permissions': const [],
        'held': const [],
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
        'creditBalance': balance,
        'examinedSkills': ['listening', 'reading'],
        'examDate': null,
      });
    }
    if (options.path == '/api/learner/wallet') {
      return FakeHttpClientAdapter.jsonResponse({
        'creditsPurchased': 20,
        'creditsUsed': 20 - balance,
        'balance': balance,
        'ledger': const [],
        'orders': const [],
      });
    }
    if (options.path == '/api/packages') {
      return FakeHttpClientAdapter.jsonResponse(const []);
    }
    return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
  });
}

void main() {
  testWidgets(
    'directory shows real names, session length, credit cost and rating',
    (tester) async {
      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse([
            _humanSummary(),
            _aiSummary(),
          ]);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        return null;
      });

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      expect(find.text('Dr. Trần Minh Khoa'), findsOneWidget);
      expect(find.text('AI Mentor — TOEIC Coach'), findsOneWidget);

      // Real session length, credit cost and a one-decimal rating.
      expect(find.text('60 MIN · 3 CREDITS · ★ 5.0'), findsOneWidget);
      // An unrated AI mentor omits the star rather than printing 0.0.
      expect(find.text('60 MIN · 1 CREDITS'), findsOneWidget);
    },
  );

  testWidgets(
    'booking screen lists real slots, the real price, and books the opened mentor',
    (tester) async {
      Map<String, dynamic>? bookPayload;
      String? bookPath;

      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse([_humanSummary()]);
        }
        if (options.path == '/api/mentors/1') {
          return FakeHttpClientAdapter.jsonResponse({
            'mentor': _humanSummary(),
            'availableSlots': [
              _slot(3, '2026-11-14T09:00:00+07:00', '2026-11-14T10:00:00+07:00'),
              _slot(4, '2026-11-16T09:00:00+07:00', '2026-11-16T10:00:00+07:00'),
            ],
            'reviews': const [],
          });
        }
        if (options.path == '/api/mentors/1/book' && options.method == 'POST') {
          bookPath = options.path;
          bookPayload = Map<String, dynamic>.from(body as Map);
          return FakeHttpClientAdapter.jsonResponse({
            'bookingId': 901,
            'userId': 2,
            'mentorId': 1,
            'mentorName': 'Dr. Trần Minh Khoa',
            'mentorType': 'human',
            'slotId': body['slotId'],
            'status': 'confirmed',
            'meetLink': 'https://meet.google.com/abc-defg-hij',
            'focusArea': body['focusArea'],
            'priceCredits': 3,
            'createdAt': '2026-11-14T09:00:00+07:00',
          }, statusCode: 201);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        return null;
      });

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      await tester.tap(find.byKey(const Key('open-mentor-1')));
      await tester.pumpAndSettle();

      // The envelope is unwrapped: the price is the mentor's, not zero.
      expect(find.text('60 MIN · 3 CREDITS'), findsOneWidget);
      // Both recorded slots are listed, each with a date and both bounds.
      // Asserted by shape, not by hour, because the label renders local time.
      expect(find.byKey(const Key('mentor-slot-3')), findsOneWidget);
      expect(find.byKey(const Key('mentor-slot-4')), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}-\d{2}:\d{2}$'),
        ),
        findsNWidgets(2),
      );

      await tester.tap(find.byKey(const Key('mentor-slot-3')));
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

      // The booking reaches the mentor that was opened, with the chosen slot.
      expect(bookPath, '/api/mentors/1/book');
      expect(bookPayload?['slotId'], 3);
      expect(bookPayload?['focusArea'], 'Part 7 inference');
    },
  );

  testWidgets(
    'an AI mentor books without a slot and says so',
    (tester) async {
      Map<String, dynamic>? aiPayload;

      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse([_aiSummary()]);
        }
        if (options.path == '/api/mentors/2') {
          return FakeHttpClientAdapter.jsonResponse({
            'mentor': _aiSummary(),
            'availableSlots': const [],
            'reviews': const [],
          });
        }
        if (options.path == '/api/mentors/2/book' && options.method == 'POST') {
          aiPayload = Map<String, dynamic>.from(body as Map);
          return FakeHttpClientAdapter.jsonResponse({
            'bookingId': 902,
            'userId': 2,
            'mentorId': 2,
            'mentorName': 'AI Mentor — TOEIC Coach',
            'mentorType': 'ai',
            'slotId': null,
            'status': 'confirmed',
            'priceCredits': 1,
            'createdAt': '2026-11-14T09:00:00+07:00',
          }, statusCode: 201);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        return null;
      });

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      await tester.tap(find.byKey(const Key('open-mentor-2')));
      await tester.pumpAndSettle();

      expect(find.text('Immediate AI session'), findsOneWidget);
      expect(
        find.text('AI mentors book immediately without a time slot.'),
        findsOneWidget,
      );
      expect(find.text('SELECT A SLOT'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const Key('confirm-booking-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking-button')));
      await tester.pumpAndSettle();

      expect(aiPayload, isNotNull);
      expect(aiPayload?['slotId'], isNull);
    },
  );

  testWidgets(
    'a failed booking reports the backend message and leaves the button usable',
    (tester) async {
      var attempts = 0;

      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse([_humanSummary()]);
        }
        if (options.path == '/api/mentors/1') {
          return FakeHttpClientAdapter.jsonResponse({
            'mentor': _humanSummary(),
            'availableSlots': [
              _slot(3, '2026-11-14T09:00:00+07:00', '2026-11-14T10:00:00+07:00'),
            ],
            'reviews': const [],
          });
        }
        if (options.path == '/api/mentors/1/book' && options.method == 'POST') {
          attempts++;
          return FakeHttpClientAdapter.jsonResponse({
            'title': 'Mentor booking error',
            'status': 400,
            'detail': 'The selected slot is no longer available.',
            'code': 'slot_not_available',
          }, statusCode: 400);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        return null;
      });

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      await tester.tap(find.byKey(const Key('open-mentor-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mentor-slot-3')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('confirm-booking-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('booking-error')), findsOneWidget);
      expect(
        find.text('The selected slot is no longer available.'),
        findsOneWidget,
      );

      // The control is still usable, so a retry is possible.
      await tester.ensureVisible(
        find.byKey(const Key('confirm-booking-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking-button')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );

  testWidgets(
    'a learner short of credits is told before submitting',
    (tester) async {
      var booked = false;

      final adapter = _adapter(
        (options, body) async {
          if (options.path == '/api/mentors') {
            return FakeHttpClientAdapter.jsonResponse([_humanSummary()]);
          }
          if (options.path == '/api/mentors/1') {
            return FakeHttpClientAdapter.jsonResponse({
              'mentor': _humanSummary(),
              'availableSlots': [
                _slot(
                  3,
                  '2026-11-14T09:00:00+07:00',
                  '2026-11-14T10:00:00+07:00',
                ),
              ],
              'reviews': const [],
            });
          }
          if (options.path == '/api/mentors/1/book') {
            booked = true;
            return FakeHttpClientAdapter.jsonResponse({}, statusCode: 201);
          }
          if (options.path == '/api/mentors/bookings') {
            return FakeHttpClientAdapter.jsonResponse(const []);
          }
          return null;
        },
        // The mentor costs 3 credits; this learner holds 1.
        creditBalance: () => 1,
      );

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      await tester.tap(find.byKey(const Key('open-mentor-1')));
      await tester.pumpAndSettle();

      expect(find.text('Not enough credits'), findsOneWidget);
      expect(
        find.textContaining('costs 3 credits and you have 1'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('confirm-booking-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking-button')));
      await tester.pumpAndSettle();

      expect(booked, isFalse);
    },
  );

  testWidgets(
    'bookings display the meet link, cancel with refund, and rate a done session',
    (tester) async {
      final urlLauncher = _RecordingUrlLauncher();
      var cancelled = false;
      var creditBalance = 12;
      Map<String, dynamic>? ratingPayload;

      Map<String, dynamic> booking2() => {
            'bookingId': 2,
            'userId': 2,
            'mentorId': 1,
            'mentorName': 'Dr. Trần Minh Khoa',
            'mentorType': 'human',
            'slotId': 6,
            'startAt': '2026-11-13T01:44:01+07:00',
            'endAt': '2026-11-13T02:44:01+07:00',
            'status': cancelled ? 'cancelled' : 'confirmed',
            'meetLink': 'https://meet.google.com/abc-defg-hij',
            'focusArea': 'Part 7 inference',
            'priceCredits': 1,
            'cancelledAt': null,
            'createdAt': '2026-11-10T01:44:01+07:00',
            'review': null,
          };

      Map<String, dynamic> booking1() => {
            'bookingId': 1,
            'userId': 2,
            'mentorId': 1,
            'mentorName': 'Dr. Trần Minh Khoa',
            'mentorType': 'human',
            'slotId': 5,
            'startAt': '2026-11-06T01:44:01+07:00',
            'endAt': '2026-11-06T02:44:01+07:00',
            'status': 'done',
            'meetLink': null,
            'focusArea': null,
            'priceCredits': 1,
            'cancelledAt': null,
            'createdAt': '2026-11-06T01:44:01+07:00',
            'review': ratingPayload == null
                ? null
                : {
                    'reviewId': 2,
                    'rating': ratingPayload!['rating'],
                    'text': ratingPayload!['text'],
                    'userDisplayName': 'Demo Learner',
                    'createdAt': '2026-11-07T01:44:01+07:00',
                  },
          };

      final adapter = _adapter(
        (options, body) async {
          if (options.path == '/api/mentors') {
            return FakeHttpClientAdapter.jsonResponse(const []);
          }
          if (options.path == '/api/mentors/bookings') {
            return FakeHttpClientAdapter.jsonResponse([booking2(), booking1()]);
          }
          if (options.path == '/api/mentors/bookings/2/cancel' &&
              options.method == 'POST') {
            cancelled = true;
            creditBalance += 1;
            return FakeHttpClientAdapter.jsonResponse({
              'bookingId': 2,
              'status': 'cancelled',
              'cancelledAt': '2026-11-13T17:00:00+00:00',
              'refundedCredits': 1,
            });
          }
          if (options.path == '/api/mentors/bookings/1/rate' &&
              options.method == 'POST') {
            ratingPayload = Map<String, dynamic>.from(body as Map);
            return FakeHttpClientAdapter.jsonResponse({
              'reviewId': 2,
              'rating': body['rating'],
              'text': body['text'],
              'userDisplayName': 'Demo Learner',
              'createdAt': '2026-11-07T01:44:01+07:00',
            });
          }
          return null;
        },
        creditBalance: () => creditBalance,
      );

      await _pumpWallet(tester, adapter, urlLauncher: urlLauncher);
      await _openMentorsTab(tester);

      await tester.ensureVisible(find.byKey(const Key('join-meet-button-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('join-meet-button-2')));
      await tester.pumpAndSettle();
      expect(urlLauncher.launchedUrls, ['https://meet.google.com/abc-defg-hij']);

      await tester.ensureVisible(
        find.byKey(const Key('cancel-booking-button-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-booking-button-2')));
      await tester.pumpAndSettle();
      expect(find.text('13 CREDITS'), findsOneWidget);
      // The refund the backend granted is reported, not assumed from the price.
      expect(find.byKey(const Key('cancel-notice-2')), findsOneWidget);
      expect(find.text('Booking cancelled. 1 credits refunded.'), findsOneWidget);

      // The finished ('done') booking is the ratable one.
      expect(find.byKey(const Key('rate-booking-button-1')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('rate-booking-button-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate-booking-button-1')));
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

      // The rating and review text are read from the booking's nested review
      // object and shown on the booking itself.
      expect(
        find.text('Rated: 5/5 — Clear feedback'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a finished session is not offered a meet link, even one the backend left',
    (tester) async {
      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse([
            {
              'bookingId': 7,
              'userId': 2,
              'mentorId': 1,
              'mentorName': 'Dr. Trần Minh Khoa',
              'mentorType': 'human',
              'slotId': 5,
              'status': 'done',
              // A stale link on an ended session: still not offered.
              'meetLink': 'https://meet.google.com/abc-defg-hij',
              'priceCredits': 1,
              'createdAt': '2026-11-06T01:44:01+07:00',
              'review': null,
            },
          ]);
        }
        return null;
      });

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      expect(find.byKey(const Key('join-meet-button-7')), findsNothing);
      // A finished, unrated session is ratable instead.
      expect(find.byKey(const Key('rate-booking-button-7')), findsOneWidget);
    },
  );

  testWidgets(
    'a failed launch says so instead of swallowing the tap',
    (tester) async {
      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse([
            {
              'bookingId': 5,
              'userId': 2,
              'mentorId': 1,
              'mentorName': 'Dr. Trần Minh Khoa',
              'mentorType': 'human',
              'slotId': 6,
              'status': 'confirmed',
              'meetLink': 'https://meet.google.com/abc-defg-hij',
              'priceCredits': 1,
              'createdAt': '2026-11-10T01:44:01+07:00',
              'review': null,
            },
          ]);
        }
        return null;
      });

      await _pumpWallet(
        tester,
        adapter,
        urlLauncher: _FailingUrlLauncher(),
      );
      await _openMentorsTab(tester);

      await tester.ensureVisible(find.byKey(const Key('join-meet-button-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('join-meet-button-5')));
      await tester.pumpAndSettle();

      expect(find.text('Could not open link'), findsOneWidget);
      expect(
        find.textContaining('https://meet.google.com/abc-defg-hij'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'a failed rating reports the backend message and leaves the rating usable',
    (tester) async {
      var attempts = 0;

      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse([
            {
              'bookingId': 1,
              'userId': 2,
              'mentorId': 1,
              'mentorName': 'Dr. Trần Minh Khoa',
              'mentorType': 'human',
              'slotId': 5,
              'status': 'done',
              'meetLink': null,
              'priceCredits': 1,
              'createdAt': '2026-11-06T01:44:01+07:00',
              'review': null,
            },
          ]);
        }
        if (options.path == '/api/mentors/bookings/1/rate') {
          attempts++;
          return FakeHttpClientAdapter.jsonResponse({
            'title': 'Mentor rating error',
            'status': 400,
            'detail': 'This booking has already been rated.',
            'code': 'booking_already_rated',
          }, statusCode: 400);
        }
        return null;
      });

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      await tester.ensureVisible(find.byKey(const Key('rate-booking-button-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate-booking-button-1')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('submit-rating-button')),
      );
      await tester.tap(find.byKey(const Key('submit-rating-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('This booking has already been rated.'),
        findsOneWidget,
      );

      // The control stays usable, so the learner can retry.
      await tester.tap(find.byKey(const Key('submit-rating-button')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );

  testWidgets(
    'a failed cancel reports the backend message and leaves the button usable',
    (tester) async {
      var attempts = 0;

      final adapter = _adapter((options, body) async {
        if (options.path == '/api/mentors') {
          return FakeHttpClientAdapter.jsonResponse(const []);
        }
        if (options.path == '/api/mentors/bookings') {
          return FakeHttpClientAdapter.jsonResponse([
            {
              'bookingId': 2,
              'userId': 2,
              'mentorId': 1,
              'mentorName': 'Dr. Trần Minh Khoa',
              'mentorType': 'human',
              'slotId': 6,
              'status': 'confirmed',
              'meetLink': 'https://meet.google.com/abc-defg-hij',
              'priceCredits': 1,
              'createdAt': '2026-11-10T01:44:01+07:00',
              'review': null,
            },
          ]);
        }
        if (options.path == '/api/mentors/bookings/2/cancel') {
          attempts++;
          return FakeHttpClientAdapter.jsonResponse({
            'title': 'Mentor booking cancellation error',
            'status': 400,
            'detail': 'Cannot cancel a session that has already started.',
            'code': 'booking_cannot_cancel',
          }, statusCode: 400);
        }
        return null;
      });

      await _pumpWallet(tester, adapter);
      await _openMentorsTab(tester);

      await tester.ensureVisible(
        find.byKey(const Key('cancel-booking-button-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-booking-button-2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancel-error-2')), findsOneWidget);
      expect(
        find.text('Cannot cancel a session that has already started.'),
        findsOneWidget,
      );

      // Not the silent `finally`: the learner can try again.
      await tester.tap(find.byKey(const Key('cancel-booking-button-2')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );
}

class _FailingUrlLauncher implements UrlLauncherAdapter {
  @override
  Future<bool> launchExternalUrl(String url) async => false;
}

Future<void> _pumpWallet(
  WidgetTester tester,
  HttpClientAdapter adapter, {
  UrlLauncherAdapter? urlLauncher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage(initialToken: 'valid-jwt'),
        ),
        httpClientAdapterProvider.overrideWithValue(adapter),
        audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
        if (urlLauncher != null)
          urlLauncherAdapterProvider.overrideWithValue(urlLauncher),
      ],
      child: const ExtraEfficientApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMentorsTab(WidgetTester tester) async {
  await tester.tap(find.text('WALLET'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wallet-subtab-mentors')));
  await tester.pumpAndSettle();
}
