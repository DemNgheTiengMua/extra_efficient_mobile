import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/widgets/signage_primitives.dart';
import '../../contract/fixture_loader.dart';
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
          return FakeHttpClientAdapter.jsonResponse(
            loadFixture('learner_complaints'),
          );
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
      // Both recorded complaints render together — no duplicate-key crash.
      expect(find.byKey(const Key('complaint-card-2')), findsOneWidget);
      expect(find.byKey(const Key('complaint-card-1')), findsOneWidget);
      expect(find.text('Booking #1 (Dr. Trần Minh Khoa)'), findsOneWidget);
      expect(find.text('REVIEWING'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
      expect(
        find.textContaining('Audio stream logs confirmed'),
        findsOneWidget,
      );
      expect(find.text('+1 CREDITS'), findsOneWidget);
      expect(find.textContaining('Audio stream froze'), findsOneWidget);
      expect(find.textContaining('mentor connection troubles'), findsOneWidget);
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
          return FakeHttpClientAdapter.jsonResponse(
            loadFixture('complaint_eligible_subjects'),
          );
        }
        if (options.path == '/api/learner/complaints' &&
            options.method == 'POST') {
          capturedPostBody = body;
          creditBalance = 38;
          complaints.add({
            'complaintId': 201,
            'type': body['type'],
            'status': 'open',
            'reason': body['reason'],
            'attemptId': body['attemptId'],
            'bookingId': body['bookingId'],
            'orderId': body['orderId'],
            'subjectSummary': 'ETS 2024 - Test 1',
            'createdAt': '2026-11-13T09:00:00Z',
            'grantedCredits': null,
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

      // The form renders despite bookings, attempts and orders sharing the
      // page: before the fix every subject parsed id 0 and the key collided.
      expect(find.text('FILE COMPLAINT'), findsOneWidget);
      expect(find.byKey(const Key('eligible-subject-attempt-1005')),
          findsOneWidget);
      expect(find.byKey(const Key('eligible-subject-booking-2')), findsOneWidget);
      expect(find.byKey(const Key('eligible-subject-booking-1')), findsOneWidget);
      expect(find.byKey(const Key('eligible-subject-order-1003')),
          findsOneWidget);

      // Each subject shows its own identifying detail.
      expect(find.text('ETS 2024 - Test 1'), findsWidgets);
      expect(find.text('Dr. Trần Minh Khoa'), findsWidgets);
      expect(find.text('DH-20261014-0001 · Intensive Pack'), findsOneWidget);

      // Two orders with different packages are visibly different.
      final intensiveOrder = find.text('DH-20261014-0001 · Intensive Pack');
      final starterOrder = find.text('DH-20261014-0002 · Starter Pack');
      expect(intensiveOrder, findsOneWidget);
      expect(starterOrder, findsOneWidget);
      expect(
        tester.widget<Text>(intensiveOrder).data,
        isNot(tester.widget<Text>(starterOrder).data),
      );

      // Select attempt 1005 and verify only attempt types are offered.
      await tester
          .ensureVisible(find.byKey(const Key('eligible-subject-attempt-1005')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('eligible-subject-attempt-1005')));
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

      // The reference carries the subject's real identifier.
      expect(capturedPostBody, {
        'type': 'grading_issue',
        'reason': 'Writing task 2 rubric score was cut off.',
        'attemptId': 1005,
      });

      // Back on Complaints Center with the new complaint & refreshed balance (38).
      expect(find.text('COMPLAINTS CENTER'), findsOneWidget);
      expect(find.byKey(const Key('complaint-card-201')), findsOneWidget);
      expect(find.textContaining('38'), findsWidgets);
    },
  );

  testWidgets(
    'a failed complaint submission reports the backend message and leaves the form usable',
    (tester) async {
      final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
      var attempts = 0;

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/auth/me') {
          return FakeHttpClientAdapter.jsonResponse(_authMeJson());
        }
        if (options.path == '/api/learner/context') {
          return FakeHttpClientAdapter.jsonResponse(_contextJson());
        }
        if (options.path == '/api/learner/complaints' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse([]);
        }
        if (options.path == '/api/learner/complaints/eligible-subjects') {
          return FakeHttpClientAdapter.jsonResponse(
            loadFixture('complaint_eligible_subjects'),
          );
        }
        if (options.path == '/api/learner/complaints' &&
            options.method == 'POST') {
          attempts++;
          return FakeHttpClientAdapter.jsonResponse({
            'title': 'Reason is required.',
            'detail': 'Reason is required.',
            'status': 400,
            'code': 'VALIDATION',
          }, statusCode: 400);
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
      final newComplaint = find.byKey(const Key('new-complaint-button'));
      await tester.ensureVisible(newComplaint);
      await tester.pumpAndSettle();
      await tester.tap(newComplaint);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('eligible-subject-booking-2')),
      );
      await tester.tap(find.byKey(const Key('eligible-subject-booking-2')));
      await tester.pumpAndSettle();
      final submitBtn = find.byKey(const Key('submit-complaint-button'));
      await tester.enterText(
        find.byKey(const Key('complaint-reason-field')),
        'Mentor never joined.',
      );
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(attempts, 1);
      // Still on the form, showing the backend's own message.
      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.text('FILE COMPLAINT'), findsOneWidget);
      expect(find.text('Reason is required.'), findsOneWidget);
      // The control is usable again, not stuck spinning.
      expect(tester.widget<PlacardButton>(submitBtn).isLoading, isFalse);
      expect(
        find.byKey(const Key('eligible-subject-booking-2')),
        findsOneWidget,
      );
      // The learner's typed reason survived the failure.
      expect(find.text('Mentor never joined.'), findsOneWidget);
    },
  );
}
