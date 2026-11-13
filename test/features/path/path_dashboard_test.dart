import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/path/screens/path_dashboard_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import 'package:forui/forui.dart';

import '../../helpers/fake_http_adapter.dart';
import 'path_fixtures.dart';

/// A router with the destinations the backend names, each rendering a marker.
/// The dashboard is reached at `/path`.
GoRouter buildRouter({String initialLocation = '/path'}) {
  Widget marker(String text) => Scaffold(body: Center(child: Text(text)));

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/path',
        builder: (context, state) => Scaffold(body: PathDashboardScreen()),
      ),
      GoRoute(
        path: '/placement',
        builder: (context, state) => marker('PLACEMENT OVERVIEW'),
      ),
      GoRoute(
        path: '/placement/take/:placementId',
        builder: (context, state) =>
            marker('PLACEMENT ROOM #${state.pathParameters['placementId']}'),
      ),
      GoRoute(
        path: '/exams/take/:attemptId',
        builder: (context, state) =>
            marker('EXAM ROOM #${state.pathParameters['attemptId']}'),
      ),
      GoRoute(
        path: '/exams/attempts/:attemptId',
        builder: (context, state) =>
            marker('ATTEMPT ROOM #${state.pathParameters['attemptId']}'),
      ),
      GoRoute(path: '/exams', builder: (context, state) => marker('EXAM HUB')),
      GoRoute(
        path: '/practice/sessions/:sessionId',
        builder: (context, state) =>
            marker('PRACTICE SESSION #${state.pathParameters['sessionId']}'),
      ),
      GoRoute(
        path: '/path/goal',
        builder: (context, state) => marker('GOAL CALIBRATION'),
      ),
      GoRoute(
        path: '/path/learning-path',
        builder: (context, state) => marker('LEARNING PATH'),
      ),
    ],
  );
}

Widget buildApp({
  required FakeHttpClientAdapter adapter,
  String initialLocation = '/path',
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage(initialToken: 'valid-jwt'),
      ),
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
      routerConfig: buildRouter(initialLocation: initialLocation),
    ),
  );
}

/// The auth + context requests every screen needs, then delegating the rest.
FakeHttpClientAdapter baseAdapter({required RouteHandler routes}) {
  return FakeHttpClientAdapter((options, body) async {
    if (options.path == '/api/auth/me') {
      return FakeHttpClientAdapter.jsonResponse({
        'userId': 2,
        'email': 'learner@demo.local',
        'fullName': 'Demo Learner',
        'role': 'learner',
        'emailVerified': true,
        'permissions': <String>[],
        'held': <String>[],
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
        'creditBalance': 11,
        'examinedSkills': ['listening', 'reading'],
        'examDate': null,
      });
    }
    return routes(options, body);
  });
}

void main() {
  /// The dashboard is a tall page; a tall viewport keeps every placard built so
  /// the assertions are about binding, not about scroll choreography.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'measured learner sees the backend band, real skill levels, and no placeholder',
    (tester) async {
      useTallViewport(tester);
      final adapter = baseAdapter(
        routes: (options, body) async {
          if (options.path == '/api/learner/dashboard') {
            return FakeHttpClientAdapter.jsonResponse(
              dashboardMeasuredPayload(),
            );
          }
          if (options.path == '/api/learner/insights/dashboard') {
            return FakeHttpClientAdapter.jsonResponse({
              'status': 'done',
              'narrative': 'Reading is your strongest skill.',
              'formattedNarrative': 'Reading is your strongest skill.',
            });
          }
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        },
      );

      await tester.pumpWidget(buildApp(adapter: adapter));
      await tester.pumpAndSettle();
      // The insight card mounts after the dashboard resolves, so its request
      // starts one frame later.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // The band and score come from goal.currentBandCode / currentScore.
      expect(find.text('10'), findsOneWidget);
      expect(find.textContaining('CURRENT BAND <A1'), findsOneWidget);
      // No target band has been set on this account, so none is invented.
      expect(find.textContaining('NO TARGET'), findsOneWidget);
      expect(find.textContaining('TARGET B2'), findsNothing);

      // Skills render with their measured level, and the unmeasured one does
      // not get a fabricated band.
      expect(find.text('LISTENING'), findsOneWidget);
      expect(find.text('BAND A2 • 5/495'), findsNWidgets(2));
      expect(find.text('SPEAKING'), findsOneWidget);
      expect(find.text('NO MEASUREMENT YET'), findsOneWidget);
      expect(find.text('NOT MEASURED'), findsOneWidget);

      // Both unfinished cards read the backend's own fields.
      expect(find.text('ETS 2024 - Test 1'), findsOneWidget);
      expect(find.text('Incomplete Sentences'), findsOneWidget);

      expect(find.text('Reading is your strongest skill.'), findsOneWidget);
    },
  );

  testWidgets(
    'never-measured learner is offered the placement test and shown no band',
    (tester) async {
      useTallViewport(tester);
      final adapter = baseAdapter(
        routes: (options, body) async {
          if (options.path == '/api/learner/dashboard') {
            return FakeHttpClientAdapter.jsonResponse(
              dashboardUnmeasuredPayload(),
            );
          }
          if (options.path == '/api/learner/insights/dashboard') {
            return FakeHttpClientAdapter.jsonResponse({
              'status': 'done',
              'formattedNarrative': 'Take the placement to see your band.',
            });
          }
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        },
      );

      await tester.pumpWidget(buildApp(adapter: adapter));
      await tester.pumpAndSettle();
      // The insight card mounts after the dashboard resolves, so its request
      // starts one frame later.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // The honest first step, worded by the backend.
      expect(find.text('Find your TOEIC level'), findsOneWidget);
      expect(
        find.textContaining('TAKE THE FREE PLACEMENT TEST'),
        findsOneWidget,
      );
      // No fabricated band and no skill ladder of blanks.
      expect(find.text('--'), findsNothing);
      expect(find.textContaining('CURRENT BAND'), findsNothing);
      expect(find.text('SKILL MEASUREMENTS'), findsNothing);

      await tester.tap(find.byKey(const Key('take-placement-test-btn')));
      await tester.pumpAndSettle();

      expect(find.text('PLACEMENT OVERVIEW'), findsOneWidget);
    },
  );

  testWidgets(
    'unmeasured learner with an open placement is offered the way back, not a dead start',
    (tester) async {
      useTallViewport(tester);
      final adapter = baseAdapter(
        routes: (options, body) async {
          if (options.path == '/api/learner/dashboard') {
            return FakeHttpClientAdapter.jsonResponse(
              dashboardUnmeasuredWithOpenPlacementPayload(),
            );
          }
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        },
      );

      await tester.pumpWidget(buildApp(adapter: adapter));
      await tester.pumpAndSettle();
      // The insight card mounts after the dashboard resolves, so its request
      // starts one frame later.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // No band and no skill ladder: nothing has been measured.
      expect(find.textContaining('CURRENT BAND'), findsNothing);
      expect(find.text('SKILL MEASUREMENTS'), findsNothing);

      // The action goes where the server said, and the unfinished attempt keeps
      // its own RESUME ATTEMPT door — both address the same room by the same
      // server-supplied URL, so neither is a dead end.
      expect(
        find.text('Finish TOEIC Placement Test - Diagnostic'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('resume-attempt-btn')), findsOneWidget);
      expect(find.text('Incomplete Sentences'), findsOneWidget);

      await tester.tap(find.byKey(const Key('resume-attempt-btn')));
      await tester.pumpAndSettle();
      expect(find.text('PLACEMENT ROOM #2'), findsOneWidget);
    },
  );

  testWidgets('NEXT ACTION navigates to the destination the backend supplies', (
    tester,
  ) async {
    useTallViewport(tester);
    final adapter = baseAdapter(
      routes: (options, body) async {
        if (options.path == '/api/learner/dashboard') {
          return FakeHttpClientAdapter.jsonResponse(dashboardMeasuredPayload());
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      },
    );

    await tester.pumpWidget(buildApp(adapter: adapter));
    await tester.pumpAndSettle();
    // The insight card mounts after the dashboard resolves, so its request
    // starts one frame later.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Finish ETS 2024 - Test 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-action-btn')));
    await tester.pumpAndSettle();

    // actionUrl was /exams/take/1005 — not a type-based guess.
    expect(find.text('EXAM ROOM #1005'), findsOneWidget);
  });

  testWidgets('RESUME ATTEMPT opens the attempt itself, not the hub', (
    tester,
  ) async {
    useTallViewport(tester);
    final adapter = baseAdapter(
      routes: (options, body) async {
        if (options.path == '/api/learner/dashboard') {
          return FakeHttpClientAdapter.jsonResponse(dashboardMeasuredPayload());
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      },
    );

    await tester.pumpWidget(buildApp(adapter: adapter));
    await tester.pumpAndSettle();
    // The insight card mounts after the dashboard resolves, so its request
    // starts one frame later.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('resume-attempt-btn')));
    await tester.pumpAndSettle();

    expect(find.text('EXAM ROOM #1005'), findsOneWidget);
    expect(find.text('EXAM HUB'), findsNothing);
  });

  testWidgets('RESUME PRACTICE opens the session itself', (tester) async {
    useTallViewport(tester);
    final adapter = baseAdapter(
      routes: (options, body) async {
        if (options.path == '/api/learner/dashboard') {
          return FakeHttpClientAdapter.jsonResponse(dashboardMeasuredPayload());
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      },
    );

    await tester.pumpWidget(buildApp(adapter: adapter));
    await tester.pumpAndSettle();
    // The insight card mounts after the dashboard resolves, so its request
    // starts one frame later.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('resume-practice-btn')));
    await tester.pumpAndSettle();

    expect(find.text('PRACTICE SESSION #4'), findsOneWidget);
  });

  testWidgets('a pending insight offers no RETRY control', (tester) async {
    useTallViewport(tester);
    final adapter = baseAdapter(
      routes: (options, body) async {
        if (options.path == '/api/learner/dashboard') {
          return FakeHttpClientAdapter.jsonResponse(dashboardMeasuredPayload());
        }
        if (options.path == '/api/learner/insights/dashboard') {
          return FakeHttpClientAdapter.jsonResponse(
            dashboardInsightPendingPayload(),
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      },
    );

    await tester.pumpWidget(buildApp(adapter: adapter));
    await tester.pumpAndSettle();
    // The insight card mounts after the dashboard resolves, so its request
    // starts one frame later.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('PENDING'), findsOneWidget);
    expect(find.byKey(const Key('retry-dashboard-insight-btn')), findsNothing);
  });

  testWidgets(
    'a failed insight offers RETRY and reports the retried narrative',
    (tester) async {
      useTallViewport(tester);
      var retried = 0;
      var status = 'failed';
      final adapter = baseAdapter(
        routes: (options, body) async {
          if (options.path == '/api/learner/dashboard') {
            return FakeHttpClientAdapter.jsonResponse(
              dashboardMeasuredPayload(),
            );
          }
          if (options.path == '/api/learner/insights/dashboard' &&
              options.method == 'GET') {
            return FakeHttpClientAdapter.jsonResponse({
              'status': status,
              'narrative': status == 'failed' ? null : 'Recovered narrative.',
              'failureReason': 'model timeout',
            });
          }
          if (options.path == '/api/learner/insights/dashboard/retry' &&
              options.method == 'POST') {
            retried++;
            status = 'done';
            // The real retry endpoint answers 204 No Content.
            return FakeHttpClientAdapter.jsonResponse(null, statusCode: 204);
          }
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        },
      );

      await tester.pumpWidget(buildApp(adapter: adapter));
      await tester.pumpAndSettle();
      // The insight card mounts after the dashboard resolves, so its request
      // starts one frame later.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('model timeout'), findsOneWidget);
      final retryBtn = find.byKey(const Key('retry-dashboard-insight-btn'));
      await tester.scrollUntilVisible(retryBtn, 300);
      await tester.pumpAndSettle();
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(retried, 1);
      expect(find.text('Recovered narrative.'), findsOneWidget);
    },
  );
}
