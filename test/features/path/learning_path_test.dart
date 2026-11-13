import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/path/screens/learning_path_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';

import '../../helpers/fake_http_adapter.dart';
import 'path_fixtures.dart';

/// The learning-path screen against the recorded payloads: no path means an
/// offer to generate (once a target band exists), a path means its real weeks,
/// remaining time and progress, and an insight only when a path exists.
void main() {
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget buildApp(FakeHttpClientAdapter adapter) {
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
        routerConfig: GoRouter(
          initialLocation: '/path/learning-path',
          routes: [
            GoRoute(
              path: '/path/learning-path',
              builder: (context, state) => Scaffold(body: LearningPathScreen()),
            ),
            GoRoute(
              path: '/path/goal',
              builder: (context, state) =>
                  Scaffold(body: Center(child: Text('GOAL CALIBRATION'))),
            ),
            GoRoute(
              path: '/practice/:sessionId',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text('PRACTICE ${state.pathParameters['sessionId']}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FakeHttpClientAdapter adapterWith({
    required Map<String, dynamic> learningPath,
    required Map<String, dynamic> targetBand,
    int generateStatus = 200,
    Map<String, dynamic>? stepStart,
    int stepStartStatus = 200,
    int insightStatus = 404,
    void Function(int stepId)? onStart,
  }) {
    return FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/auth/me') {
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'email': 'learner@demo.local',
          'fullName': 'Demo Learner',
          'role': 'learner',
          'emailVerified': true,
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
        });
      }
      if (options.path == '/api/learner/target-band' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(targetBand);
      }
      if (options.path == '/api/learner/learning-path' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(learningPath);
      }
      if (options.path == '/api/learner/learning-path/generate') {
        return FakeHttpClientAdapter.jsonResponse(
          {'hasActivePath': false},
          statusCode: generateStatus,
        );
      }
      final startMatch = RegExp(
        r'^/api/learner/learning-path/steps/(\d+)/start$',
      ).firstMatch(options.path);
      if (startMatch != null) {
        onStart?.call(int.parse(startMatch.group(1)!));
        return FakeHttpClientAdapter.jsonResponse(
          stepStart ?? startStepResultPayload(),
          statusCode: stepStartStatus,
        );
      }
      if (options.path == '/api/learner/insights/path' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: insightStatus);
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });
  }

  testWidgets(
    'no active path and no target band: generation is not offered, the '
    'missing prerequisite is named',
    (tester) async {
      useTallViewport(tester);
      var generateCalls = 0;
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/learning-path/generate') {
          generateCalls++;
          return FakeHttpClientAdapter.jsonResponse(
            generateNoGoalErrorPayload(),
            statusCode: 422,
          );
        }
        return adapterWith(
          learningPath: learningPathSummaryEmptyPayload(),
          targetBand: targetBandNoGoalPayload(),
        ).handler(options, body);
      });

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();

      // `hasActivePath: false` is the existence switch, so the empty shell of
      // weeks is replaced by an offer — but the offer is gated.
      expect(find.text('LOADING LEARNING PATH'), findsNothing);
      expect(find.byKey(const Key('generate-learning-path-btn')), findsNothing);
      expect(find.text('Choose a target band first'), findsOneWidget);
      expect(find.byKey(const Key('set-target-band-btn')), findsOneWidget);
      expect(generateCalls, 0);
    },
  );

  testWidgets('the missing prerequisite leads to the target-band surface', (
    tester,
  ) async {
    useTallViewport(tester);
    final adapter = adapterWith(
      learningPath: learningPathSummaryEmptyPayload(),
      targetBand: targetBandNoGoalPayload(),
    );

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('set-target-band-btn')));
    await tester.pumpAndSettle();

    expect(find.text('GOAL CALIBRATION'), findsOneWidget);
  });

  testWidgets(
    'a measured band and a target band can generate a path, and its real weeks, '
    'remaining time and progress render',
    (tester) async {
      useTallViewport(tester);
      var generateCalls = 0;
      var hasPath = false;
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/learning-path' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(
            hasPath
                ? learningPathActivePayload()
                : learningPathSummaryEmptyPayload(),
          );
        }
        if (options.path == '/api/learner/learning-path/generate') {
          generateCalls++;
          hasPath = true;
          return FakeHttpClientAdapter.jsonResponse(
            learningPathActivePayload(),
          );
        }
        return adapterWith(
          learningPath: learningPathSummaryEmptyPayload(),
          targetBand: targetBandWithGoalPayload(),
        ).handler(options, body);
      });

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();

      final generateBtn = find.byKey(const Key('generate-learning-path-btn'));
      expect(generateBtn, findsOneWidget);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle();

      expect(generateCalls, 1);
      expect(find.text('TARGET B2'), findsOneWidget);
      expect(find.text('0/16'), findsOneWidget);
      expect(find.text('720 MIN'), findsWidgets);
      expect(find.text('WEEK 1'), findsOneWidget);
      expect(find.text('WEEK 4'), findsOneWidget);
      // A locked step stays visible as an unavailable line rather than hidden.
      expect(find.byKey(const Key('start-step-2')), findsOneWidget);
      expect(find.text('LOCKED'), findsWidgets);
      // The first step is the one the server says can start.
      expect(find.text('START'), findsOneWidget);
    },
  );

  testWidgets('starting a step follows the redirect URL the server supplies', (
    tester,
  ) async {
    useTallViewport(tester);
    int? startedStep;
    final adapter = adapterWith(
      learningPath: learningPathActivePayload(),
      targetBand: targetBandWithGoalPayload(),
      onStart: (stepId) => startedStep = stepId,
    );

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-step-1')));
    await tester.pumpAndSettle();

    expect(startedStep, 1);
    // `redirectUrl` in the recorded payload is `/practice/21`.
    expect(find.text('PRACTICE 21'), findsOneWidget);
  });

  testWidgets(
    'a step that is not on the active path reports a terminal state instead of '
    'crashing',
    (tester) async {
      useTallViewport(tester);
      final adapter = adapterWith(
        learningPath: learningPathActivePayload(),
        targetBand: targetBandWithGoalPayload(),
        stepStart: stepNotFoundPayload(),
        stepStartStatus: 404,
      );

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start-step-1')));
      await tester.pumpAndSettle();

      expect(find.text('Cannot open that step'), findsOneWidget);
      expect(
        find.textContaining('is not on your active path'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the path insight is absent while no path exists', (
    tester,
  ) async {
    useTallViewport(tester);
    var insightRequests = 0;
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/insights/path') {
        insightRequests++;
      }
      return adapterWith(
        learningPath: learningPathSummaryEmptyPayload(),
        targetBand: targetBandWithGoalPayload(),
      ).handler(options, body);
    });

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(insightRequests, 0);
    expect(find.text('PATH INSIGHT'), findsNothing);
  });

  testWidgets(
    'a redirect the app has not registered does not crash the screen',
    (tester) async {
      useTallViewport(tester);
      // The backend's NEXT ACTION can name `/learning-path/steps/{id}`, which
      // this table has no route for. The global fallback is #12's; this only
      // proves the path screen survives the push.
      final adapter = adapterWith(
        learningPath: learningPathActivePayload(),
        targetBand: targetBandWithGoalPayload(),
        stepStart: {
          ...startStepResultPayload(),
          'redirectUrl': '/learning-path/steps/1',
        },
      );

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start-step-1')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

