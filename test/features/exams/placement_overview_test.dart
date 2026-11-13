import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/features/exams/screens/placement_overview_screen.dart';
import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  Widget buildApp(FakeHttpClientAdapter adapter) {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final router = GoRouter(
      initialLocation: '/placement',
      routes: [
        GoRoute(
          path: '/placement',
          builder: (context, state) => const PlacementOverviewScreen(),
        ),
        GoRoute(
          path: '/placement/take/:placementId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'PLACEMENT ROOM #${state.pathParameters['placementId']}',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/placement/take/:placementId/preflight',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'PLACEMENT PREFLIGHT #${state.pathParameters['placementId']}',
              ),
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        httpClientAdapterProvider.overrideWithValue(adapter),
        audioMediaAdapterProvider.overrideWithValue(FakeAudioMediaAdapter()),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          useMaterial3: false,
          scaffoldBackgroundColor: SignageColors.wall,
        ),
        builder: (context, child) => FTheme(
          data: buildSignageTheme(),
          child: child ?? const SizedBox.shrink(),
        ),
        routerConfig: router,
      ),
    );
  }

  /// Recorded `GET /api/learner/placement` shape: the envelope.
  Map<String, dynamic> catalogPayload({
    bool isRetake = false,
    int? activePlacementId,
    bool includeExam = true,
  }) => {
    'activeCert': {
      'code': 'TOEIC',
      'name': 'TOEIC Listening & Reading',
      'sectionNoun': 'Part',
    },
    'currentBandCode': null,
    'currentBandName': null,
    'currentTotalScore': null,
    'exams': [
      if (includeExam)
        {
          'examId': 101,
          'certId': 1,
          'certCode': 'TOEIC',
          'name': 'TOEIC Diagnostic Placement',
          'description': 'A diagnostic across all four skills.',
          'durationMinutes': 45,
          'questionCount': 29,
          'isRecommended': true,
          'activePlacementId': activePlacementId,
        },
    ],
    'activePlacementId': activePlacementId,
    'activeAttemptId': 3,
    'isRetake': isRetake,
    'allSkillsRetakeCredits': 5,
    'listeningAndReadingRetakeCredits': 3,
    'creditBalance': null,
  };

  /// Recorded `GET /api/learner/placement/preflight` shape: offers, not scopes.
  Map<String, dynamic> preflightPayload() => {
    'certId': 1,
    'certCode': 'TOEIC',
    'examId': 101,
    'offers': [
      {
        'skillId': 1,
        'skillCode': 'LIST',
        'skillName': 'Listening',
        'modality': 'listening',
        'requiresMicrophone': false,
        'requiresAudio': true,
        'levelCode': 'A2',
        'positionInBand': 13,
        'measuredAt': '2026-11-13T16:00:07Z',
        'expiresAt': '2027-02-11T16:00:07Z',
        'canReuse': true,
        'isAged': false,
      },
    ],
    'cooldownUntil': null,
    'cooldownWaived': false,
    'hasReusableSkills': true,
    'isStartable': true,
    'requiresMicrophone': true,
    'requiresAudio': true,
    'isRetake': false,
    'allSkillsRetakeCredits': 5,
    'listeningAndReadingRetakeCredits': 3,
    'creditBalance': null,
  };

  testWidgets('free first placement shows the free badge and starts with the '
      'catalogue exam id', (tester) async {
    Map<String, dynamic>? startPayload;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(catalogPayload());
      }
      if (options.path == '/api/learner/placement/preflight' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(preflightPayload());
      }
      if (options.path == '/api/learner/placement/start' &&
          options.method == 'POST') {
        startPayload = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({'placementId': 555});
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    expect(find.text('FREE FIRST PLACEMENT'), findsOneWidget);
    expect(find.text('TOEIC Diagnostic Placement'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('start-placement-btn')),
      200,
    );
    await tester.tap(find.byKey(const Key('start-placement-btn')));
    await tester.pumpAndSettle();

    expect(startPayload, isNotNull);
    expect(startPayload!['examId'], 101);
    expect(startPayload!['scope'], 'all_skills');
    // A freshly started sitting takes the same device gate as a resumed one.
    expect(find.text('PLACEMENT PREFLIGHT #555'), findsOneWidget);
  });

  testWidgets('paid retake offers both scopes at the catalogue prices and '
      'sends the chosen one', (tester) async {
    Map<String, dynamic>? startPayload;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(
          catalogPayload(isRetake: true),
        );
      }
      if (options.path == '/api/learner/placement/preflight' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(preflightPayload());
      }
      if (options.path == '/api/learner/placement/start' &&
          options.method == 'POST') {
        startPayload = body as Map<String, dynamic>?;
        return FakeHttpClientAdapter.jsonResponse({'placementId': 777});
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    expect(find.text('PAID RETAKE'), findsOneWidget);
    expect(find.text('5 CREDITS'), findsOneWidget);
    expect(find.text('3 CREDITS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('scope-option-listening_and_reading')),
      200,
    );
    await tester.tap(
      find.byKey(const Key('scope-option-listening_and_reading')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('start-placement-btn')),
      200,
    );
    await tester.tap(find.byKey(const Key('start-placement-btn')));
    await tester.pumpAndSettle();

    expect(startPayload, isNotNull);
    expect(startPayload!['scope'], 'listening_and_reading');
  });

  testWidgets('an unfinished placement offers RESUME into its room', (
    tester,
  ) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(
          catalogPayload(activePlacementId: 41),
        );
      }
      if (options.path == '/api/learner/placement/preflight' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(preflightPayload());
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    expect(find.text('IN-PROGRESS ATTEMPT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resume-placement-btn')));
    await tester.pumpAndSettle();
    // RESUME goes through the device gate, not straight into the room.
    expect(find.text('PLACEMENT PREFLIGHT #41'), findsOneWidget);
  });

  testWidgets('no published exam disables the start control', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(
          catalogPayload(includeExam: false),
        );
      }
      if (options.path == '/api/learner/placement/preflight' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(preflightPayload());
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    expect(find.text('NO PLACEMENT EXAM AVAILABLE'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('start-placement-btn')),
      200,
    );
    // A disabled control renders at the dimmed opacity and does not navigate.
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('start-placement-btn')),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(1));

    await tester.tap(find.byKey(const Key('start-placement-btn')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PLACEMENT ROOM'), findsNothing);
  });
}
