import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/path/screens/path_dashboard_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';

import '../../helpers/fake_http_adapter.dart';
import 'path_fixtures.dart';

/// The dashboard is a tall page; a tall viewport keeps every placard built so
/// the assertions are about binding, not about scroll choreography.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Every destination the backend names, each rendering a marker. The dashboard
/// is reached at `/path`.
Widget buildApp({
  required FakeHttpClientAdapter adapter,
  String initialLocation = '/path',
}) {
  Widget marker(String text) => Scaffold(body: Center(child: Text(text)));

  final router = GoRouter(
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
        path: '/speaking/take/:attemptId',
        builder: (context, state) =>
            marker('SPEAKING ROOM #${state.pathParameters['attemptId']}'),
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
      routerConfig: router,
    ),
  );
}

/// The auth + context requests every screen needs, then the test's own routes.
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

/// Pump, then let the insight card's request (started one frame after the
/// dashboard resolves) settle too.
Future<void> pumpDashboard(
  WidgetTester tester,
  FakeHttpClientAdapter adapter,
) async {
  await tester.pumpWidget(buildApp(adapter: adapter));
  await tester.pumpAndSettle();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'measured learner sees the backend band and real skill levels, with no placeholder',
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
            return FakeHttpClientAdapter.jsonResponse(
              dashboardInsightDonePayload(),
            );
          }
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        },
      );

      await pumpDashboard(tester, adapter);

      // The band and score come from goal.currentBandCode / currentScore.
      expect(find.text('10'), findsOneWidget);
      expect(find.textContaining('CURRENT BAND <A1'), findsOneWidget);
      // No target band has been set on this account, so none is invented.
      expect(find.textContaining('NO TARGET'), findsOneWidget);
      expect(find.textContaining('TARGET B2'), findsNothing);

      // Skills render with their measured level; the unmeasured pair does not.
      expect(find.text('LISTENING'), findsOneWidget);
      expect(find.text('BAND A2 • 5/495'), findsNWidgets(2));
      expect(find.text('SPEAKING'), findsOneWidget);
      expect(find.text('NO MEASUREMENT YET'), findsNWidgets(2));
      expect(find.text('NOT MEASURED'), findsNWidgets(2));

      // The unfinished rows read the backend's own fields.
      expect(find.text('ETS TOEIC Speaking Practice Exam 1'), findsOneWidget);
      expect(find.text('Talks'), findsOneWidget);

      // The insight body is the recorded narrative, not a placeholder.
      expect(find.textContaining('Performance Summary'), findsOneWidget);
    },
  );

  testWidgets(
    'a never-measured learner with nothing open is offered the placement test',
    (tester) async {
      useTallViewport(tester);
      final adapter = baseAdapter(
        routes: (options, body) async {
          if (options.path == '/api/learner/dashboard') {
            return FakeHttpClientAdapter.jsonResponse(
              dashboardUnmeasuredNoSittingPayload(),
            );
          }
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        },
      );

      await pumpDashboard(tester, adapter);

      // The honest first step, worded and addressed by the backend.
      expect(find.text('Find your TOEIC level'), findsOneWidget);
      expect(find.textContaining('FREE'), findsOneWidget);
      // No fabricated band and no skills ladder of blanks.
      expect(find.text('--'), findsNothing);
      expect(find.textContaining('CURRENT BAND'), findsNothing);
      expect(find.text('SKILL MEASUREMENTS'), findsNothing);
      expect(find.byKey(const Key('resume-attempt-btn')), findsNothing);

      await tester.tap(find.byKey(const Key('take-placement-test-btn')));
      await tester.pumpAndSettle();
      expect(find.text('PLACEMENT OVERVIEW'), findsOneWidget);
    },
  );

  testWidgets(
    'a never-measured learner with an open placement keeps the way back',
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

      await pumpDashboard(tester, adapter);

      // Still no band: nothing has been measured.
      expect(find.textContaining('CURRENT BAND'), findsNothing);
      expect(find.text('SKILL MEASUREMENTS'), findsNothing);

      // The first step is the backend's resume action for the open sitting.
      expect(
        find.textContaining('Finish TOEIC Placement Test'),
        findsOneWidget,
      );
      expect(find.text('TAKE THE FREE PLACEMENT TEST'), findsNothing);
      expect(find.byKey(const Key('resume-attempt-btn')), findsOneWidget);

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

    await pumpDashboard(tester, adapter);

    expect(
      find.text('Finish ETS TOEIC Speaking Practice Exam 1'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('next-action-btn')));
    await tester.pumpAndSettle();

    // actionUrl was /speaking/take/1006 — not a type-based guess.
    expect(find.text('SPEAKING ROOM #1006'), findsOneWidget);
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

    await pumpDashboard(tester, adapter);

    await tester.tap(find.byKey(const Key('resume-attempt-btn')));
    await tester.pumpAndSettle();

    expect(find.text('SPEAKING ROOM #1006'), findsOneWidget);
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

    await pumpDashboard(tester, adapter);

    await tester.tap(find.byKey(const Key('resume-practice-btn')));
    await tester.pumpAndSettle();

    expect(find.text('PRACTICE SESSION #16'), findsOneWidget);
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

    await pumpDashboard(tester, adapter);

    expect(find.text('PENDING'), findsOneWidget);
    expect(find.byKey(const Key('retry-dashboard-insight-btn')), findsNothing);
  });

  testWidgets(
    'a failed insight offers RETRY, and the retried insight is shown',
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
              ...dashboardInsightDonePayload(),
              'status': status,
              'narrative': status == 'failed' ? null : 'Recovered narrative.',
              'failureReason': status == 'failed' ? 'model timeout' : null,
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

      await pumpDashboard(tester, adapter);

      expect(find.text('model timeout'), findsOneWidget);
      final retryBtn = find.byKey(const Key('retry-dashboard-insight-btn'));
      expect(retryBtn, findsOneWidget);

      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(retried, 1);
      expect(find.text('Recovered narrative.'), findsOneWidget);
      expect(retryBtn, findsNothing);
    },
  );
}
