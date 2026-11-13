import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import '../../helpers/fake_http_adapter.dart';

Widget _buildTestApp(
  FakeHttpClientAdapter adapter,
  InMemoryTokenStorage tokenStorage,
) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokenStorage),
      httpClientAdapterProvider.overrideWithValue(adapter),
      audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
    ],
    child: const ExtraEfficientApp(),
  );
}

Map<String, dynamic> _authMeJson({String fullName = 'Demo Learner'}) => {
      'userId': 2,
      'email': 'learner@demo.local',
      'fullName': fullName,
      'role': 'learner',
      'emailVerified': true,
      'permissions': <String>[],
      'held': <String>[],
    };

Map<String, dynamic> _contextJson({int creditBalance = 13}) => {
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
    };

void main() {
  testWidgets(
    'learner views and updates personal profile via GET/PUT /api/profile',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      var fullName = 'Demo Learner';
      String? phone = '+84901234567';
      var timeZoneId = 'Asia/Ho_Chi_Minh';
      Map<String, dynamic>? capturedPutBody;

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/me') {
          return FakeHttpClientAdapter.jsonResponse(
            _authMeJson(fullName: fullName),
          );
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse(_contextJson());
        }
        if (options.path == '/api/profile' && options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'userId': 2,
            'email': 'learner@demo.local',
            'fullName': fullName,
            'phone': phone,
            'timeZoneId': timeZoneId,
            'emailVerified': true,
          });
        }
        if (options.path == '/api/profile' && options.method == 'PUT') {
          capturedPutBody = body;
          fullName = body['fullName'] as String;
          phone = body['phone'] as String?;
          timeZoneId = body['timeZoneId'] as String;
          return FakeHttpClientAdapter.jsonResponse({
            'userId': 2,
            'email': 'learner@demo.local',
            'fullName': fullName,
            'phone': phone,
            'timeZoneId': timeZoneId,
            'emailVerified': true,
          });
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(_buildTestApp(adapter, tokenStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACCOUNT'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-profile-button')));
      await tester.pumpAndSettle();

      expect(find.text('PROFILE & PASSWORD'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('profile-full-name-field')),
        'Nguyen Van B',
      );
      await tester.enterText(
        find.byKey(const Key('profile-phone-field')),
        '+84987654321',
      );
      await tester.enterText(
        find.byKey(const Key('profile-timezone-field')),
        'Asia/Tokyo',
      );
      await tester.tap(find.byKey(const Key('save-profile-button')));
      await tester.pumpAndSettle();

      expect(capturedPutBody, {
        'fullName': 'Nguyen Van B',
        'phone': '+84987654321',
        'timeZoneId': 'Asia/Tokyo',
      });
      expect(find.textContaining('Profile updated'), findsOneWidget);
    },
  );

  testWidgets(
    'learner validates password mismatch and submits POST /api/profile/password',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      Map<String, dynamic>? capturedPasswordBody;

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/me') {
          return FakeHttpClientAdapter.jsonResponse(_authMeJson());
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse(_contextJson());
        }
        if (options.path == '/api/profile' && options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'userId': 2,
            'email': 'learner@demo.local',
            'fullName': 'Demo Learner',
            'phone': null,
            'timeZoneId': 'Asia/Ho_Chi_Minh',
            'emailVerified': true,
          });
        }
        if (options.path == '/api/profile/password' &&
            options.method == 'POST') {
          capturedPasswordBody = body;
          return FakeHttpClientAdapter.jsonResponse({'message': 'Updated'});
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(_buildTestApp(adapter, tokenStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-profile-button')));
      await tester.pumpAndSettle();

      // Scroll to password section and test mismatch validation first.
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('current-password-field')),
        'OldPass123!',
      );
      await tester.enterText(
        find.byKey(const Key('new-password-field')),
        'NewPass123!',
      );
      await tester.enterText(
        find.byKey(const Key('confirm-password-field')),
        'Different123!',
      );
      final submitButton = find.byKey(const Key('change-password-button'));
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(capturedPasswordBody, isNull);
      expect(find.text('Passwords do not match.'), findsOneWidget);

      // Fix confirmation and submit.
      await tester.enterText(
        find.byKey(const Key('confirm-password-field')),
        'NewPass123!',
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(capturedPasswordBody, {
        'currentPassword': 'OldPass123!',
        'newPassword': 'NewPass123!',
      });
      expect(find.textContaining('Password changed'), findsOneWidget);
    },
  );

  testWidgets(
    'learner views Complaints Center list with status badges, resolution notes, and grantedCredits make-good',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/me') {
          return FakeHttpClientAdapter.jsonResponse(_authMeJson());
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse(_contextJson());
        }
        if (options.path == '/api/learner/complaints' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse([
            {
              'id': 101,
              'type': 'mentor_no_show',
              'status': 'resolved',
              'reason': 'Mentor did not join the Google Meet room.',
              'bookingId': 55,
              'subjectSummary': 'Booking #55 — Speaking Coaching',
              'createdAt': '2026-11-10T08:30:00Z',
              'resolvedAt': '2026-11-11T10:15:00Z',
              'resolution': 'Verified mentor absence and refunded credits.',
              'grantedCredits': 25,
            },
            {
              'id': 102,
              'type': 'grading_issue',
              'status': 'reviewing',
              'reason': 'AI score did not match rubric criteria.',
              'attemptId': 88,
              'subjectSummary': 'Attempt #88 — IELTS Writing',
              'createdAt': '2026-11-12T14:00:00Z',
              'resolvedAt': null,
              'resolution': null,
              'grantedCredits': 0,
            },
            {
              'id': 103,
              'type': 'payment_issue',
              'status': 'open',
              'reason': 'Order paid but credits delayed.',
              'orderId': 19,
              'subjectSummary': 'Order #19 — 50 Credits Pack',
              'createdAt': '2026-11-13T07:00:00Z',
              'resolvedAt': null,
              'resolution': null,
              'grantedCredits': 0,
            },
          ]);
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(_buildTestApp(adapter, tokenStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACCOUNT'));
      await tester.pumpAndSettle();

      final openComplaints = find.byKey(const Key('open-complaints-button'));
      await tester.ensureVisible(openComplaints);
      await tester.pumpAndSettle();
      await tester.tap(openComplaints);
      await tester.pumpAndSettle();

      expect(find.text('COMPLAINTS CENTER'), findsOneWidget);
      expect(find.text('Booking #55 — Speaking Coaching'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
      expect(
        find.text('Verified mentor absence and refunded credits.'),
        findsOneWidget,
      );
      expect(find.text('+25 CREDITS'), findsOneWidget);

      expect(find.text('Attempt #88 — IELTS Writing'), findsOneWidget);
      expect(find.text('REVIEWING'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Order #19 — 50 Credits Pack'),
        200,
      );
      expect(find.text('Order #19 — 50 Credits Pack'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);
    },
  );

  testWidgets(
    'learner files a Complaint against an eligible owned subject with filtered types and refreshes list & wallet',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      var creditBalance = 13;
      final complaints = <Map<String, dynamic>>[];
      Map<String, dynamic>? capturedPostBody;

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/me') {
          return FakeHttpClientAdapter.jsonResponse(_authMeJson());
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse(
            _contextJson(creditBalance: creditBalance),
          );
        }
        if (options.path == '/api/learner/complaints' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(complaints);
        }
        if (options.path == '/api/learner/complaints/eligible-subjects' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'bookings': [
              {
                'id': 55,
                'summary': 'Booking #55 — Mentor Alice',
                'subtitle': '2026-11-10 09:00 UTC',
              },
            ],
            'attempts': [
              {
                'id': 88,
                'summary': 'Attempt #88 — IELTS Writing',
                'subtitle': '2026-11-12 14:00 UTC',
              },
            ],
            'orders': [
              {
                'id': 19,
                'summary': 'Order #19 — 50 Credits Pack',
                'subtitle': '2026-11-13 07:00 UTC',
              },
            ],
          });
        }
        if (options.path == '/api/learner/complaints' &&
            options.method == 'POST') {
          capturedPostBody = body;
          creditBalance = 38;
          complaints.add({
            'id': 201,
            'type': body['type'],
            'status': 'open',
            'reason': body['reason'],
            'attemptId': body['attemptId'],
            'subjectSummary': 'Attempt #88 — IELTS Writing',
            'createdAt': '2026-11-13T09:00:00Z',
            'grantedCredits': 0,
          });
          return FakeHttpClientAdapter.jsonResponse(complaints.last);
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(_buildTestApp(adapter, tokenStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACCOUNT'));
      await tester.pumpAndSettle();

      final openComplaints = find.byKey(const Key('open-complaints-button'));
      await tester.ensureVisible(openComplaints);
      await tester.pumpAndSettle();
      await tester.tap(openComplaints);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new-complaint-button')));
      await tester.pumpAndSettle();

      // Initially booking is not selected or first subject is selected;
      // select Attempt #88 and verify only attempt types are shown.
      await tester.tap(find.byKey(const Key('eligible-subject-attempt-88')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('complaint-type-grading_issue')), findsOneWidget);
      expect(find.byKey(const Key('complaint-type-technical_error')), findsOneWidget);
      expect(find.byKey(const Key('complaint-type-mentor_no_show')), findsNothing);
      expect(find.byKey(const Key('complaint-type-payment_issue')), findsNothing);

      // Select grading_issue, validate empty reason first.
      await tester.tap(find.byKey(const Key('complaint-type-grading_issue')));
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('submit-complaint-button'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(capturedPostBody, isNull);
      expect(find.text('Please describe the issue.'), findsOneWidget);

      // Enter reason and submit.
      await tester.enterText(
        find.byKey(const Key('complaint-reason-field')),
        'Writing task 2 rubric score was cut off.',
      );
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(capturedPostBody, {
        'type': 'grading_issue',
        'reason': 'Writing task 2 rubric score was cut off.',
        'attemptId': 88,
      });

      // Back on Complaints Center with new complaint & refreshed balance (38).
      expect(find.text('COMPLAINTS CENTER'), findsOneWidget);
      expect(find.text('Attempt #88 — IELTS Writing'), findsOneWidget);
      expect(find.textContaining('38'), findsWidgets);
    },
  );
}
