import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:extra_efficient_mobile/app.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

import '../../helpers/fake_http_adapter.dart';

/// The real application router, asserted at the route boundary.
///
/// The other exam tests build their own `GoRouter`, which would keep passing
/// even if `app_router.dart` never registered a door. This one uses
/// `ExtraEfficientApp` and proves the paths the doors navigate to actually exist.
void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    FakeHttpClientAdapter adapter,
  ) async {
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
  }

  FakeHttpClientAdapter hubAdapter({
    required ResponseBody Function(String path) onPreflight,
  }) {
    return FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/auth/me':
          return FakeHttpClientAdapter.jsonResponse({
            'userId': 2,
            'email': 'learner@demo.local',
            'fullName': 'Demo Learner',
            'role': 'learner',
            'emailVerified': true,
            'permissions': <dynamic>[],
            'held': <dynamic>[],
          });
        case 'GET /api/learner/context':
          return FakeHttpClientAdapter.jsonResponse({
            'active': {'code': 'TOEIC', 'name': 'TOEIC'},
            'certificates': [
              {'code': 'TOEIC', 'name': 'TOEIC', 'isActive': true},
            ],
            'creditBalance': 10,
          });
        case 'GET /api/learner/dashboard':
          return FakeHttpClientAdapter.jsonResponse({
            'certificate': {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'nextAction': {
              'eyebrow': 'NEXT',
              'title': 'Continue',
              'description': 'Keep going',
              'actionLabel': 'CONTINUE',
              'actionUrl': '/practice',
              'severity': 'info',
              'cascadeStep': 'practice',
            },
            'goal': {
              'currentBandCode': 'B1',
              'currentBandName': 'Intermediate',
              'hasNoMeasurement': false,
            },
            'skills': <dynamic>[],
            'attemptCount': 1,
            'practiceCount': 0,
            'unfinishedAttempt': {
              'attemptId': 1005,
              'examName': 'ETS 2024 — Test 1',
              'purpose': 'mock',
              'status': 'in_progress',
              'startedAt': '2026-11-13T16:03:15Z',
              'totalScore': null,
              'bandCode': null,
            },
          });
        case 'GET /api/learner/placement':
          return FakeHttpClientAdapter.jsonResponse({
            'activeCert': {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'exams': <dynamic>[],
            'activePlacementId': null,
            'isRetake': false,
            'allSkillsRetakeCredits': 5,
            'listeningAndReadingRetakeCredits': 3,
          });
        case 'GET /api/learner/exams':
          return FakeHttpClientAdapter.jsonResponse({
            'certificate': {
              'code': 'TOEIC',
              'name': 'TOEIC Listening & Reading',
              'sectionNoun': 'Part',
            },
            'creditBalance': 10,
            'exams': <dynamic>[],
          });
        case 'GET /api/learner/exams/history':
          return FakeHttpClientAdapter.jsonResponse({
            'certificate': {'code': 'TOEIC', 'name': 'TOEIC'},
            'totalAttempts': 0,
            'cefrBands': <dynamic>[],
            'attempts': <dynamic>[],
          });
        default:
          return onPreflight(options.path);
      }
    });
  }

  testWidgets(
      'the dashboard card opens the registered device gate, not a blank route',
      (tester) async {
    // Nothing is served for the gate, so its own error branch renders. The
    // assertion is that the route exists and paints something the learner can
    // act on - a missing registration would render GoRouter's blank error page.
    final adapter = hubAdapter(
      onPreflight: (path) => FakeHttpClientAdapter.jsonResponse(
        {'status': 404, 'code': 'ATTEMPT_NOT_FOUND', 'title': 'Not found'},
        statusCode: 404,
      ),
    );

    await pumpApp(tester, adapter);

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const Key('resume-unfinished-attempt-btn')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resume-unfinished-attempt-btn')));
    await tester.pumpAndSettle();

    // `attempt_not_found` is an honest terminal state, and it is reachable only
    // because `/exams/attempts/{id}/preflight` is a registered route.
    expect(find.text('This sitting no longer exists'), findsOneWidget);
    expect(find.text('BACK TO EXAMS'), findsWidgets);
  });
}
