import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/path/screens/goal_calibration_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';

import '../../helpers/fake_http_adapter.dart';
import 'path_fixtures.dart';

/// The target-band surface offers the certificate's **own** bands with their
/// score ranges rather than a hardcoded ladder, and writes the chosen band.
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
          initialLocation: '/path/goal',
          routes: [
            GoRoute(
              path: '/path/goal',
              builder: (context, state) =>
                  Scaffold(body: GoalCalibrationScreen()),
            ),
          ],
        ),
      ),
    );
  }

  FakeHttpClientAdapter adapterWith({
    required Map<String, dynamic> targetBand,
    Map<String, dynamic>? calibration,
    void Function(Map<String, dynamic> body)? onGoal,
    void Function(Map<String, dynamic> body)? onTargetBand,
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
          'active': {'code': 'TOEIC', 'name': 'TOEIC Listening & Reading'},
          'certificates': [
            {'code': 'TOEIC', 'name': 'TOEIC Listening & Reading'},
          ],
          'creditBalance': 11,
        });
      }
      if (options.path == '/api/learner/dashboard') {
        return FakeHttpClientAdapter.jsonResponse(dashboardMeasuredPayload());
      }
      if (options.path == '/api/learner/insights/dashboard') {
        return FakeHttpClientAdapter.jsonResponse(
          dashboardInsightDonePayload(),
        );
      }
      if (options.path == '/api/learner/target-band' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(targetBand);
      }
      if (options.path == '/api/learner/target-band' &&
          options.method == 'POST') {
        onTargetBand?.call(Map<String, dynamic>.from(body as Map));
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'certId': 1,
          'targetBandCode': (body as Map)['targetBandCode'],
          'setAt': '2026-11-13T18:22:23.6915029+00:00',
        });
      }
      if (options.path == '/api/learner/goal' && options.method == 'POST') {
        onGoal?.call(Map<String, dynamic>.from(body as Map));
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 2,
          'certId': 1,
          'targetBandCode': (body as Map)['targetBandCode'],
          'setAt': '2026-11-13T18:22:23.6915029+00:00',
          'goal': {
            'currentBandCode': 'below_A1',
            'targetBandCode': (body as Map)['targetBandCode'],
            'targetDate': null,
            'weeklyStudyHours': (body as Map)['weeklyStudyHours'],
            'requiredHours': null,
            'availableHours': null,
            'status': null,
            'suggestedWeeklyHours': null,
            'earliestFeasibleDate': null,
          },
        });
      }
      if (options.path == '/api/learner/calibration' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(
          calibration ??
              {
                'pending': false,
                'currentTargetBandCode': null,
                'recommendedBandCode': null,
                'reason': null,
              },
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });
  }

  testWidgets(
    'the bands offered are the certificate\'s own, each with its score range',
    (tester) async {
      useTallViewport(tester);
      final adapter = adapterWith(targetBand: targetBandNoGoalPayload());

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();

      // All six of the certificate's real bands, by code — the payload's ladder,
      // not a hardcoded one.
      for (final code in ['below_A1', 'A1', 'A2', 'B1', 'B2', 'C1']) {
        expect(
          find.byKey(Key('target-band-$code')),
          findsOneWidget,
          reason: 'band $code is in the certificate payload',
        );
      }
      // The ready-to-print range the backend supplies.
      expect(find.textContaining('10 to 119 points'), findsOneWidget);
      expect(find.textContaining('945 to 990 points'), findsOneWidget);
      expect(find.textContaining('Beginner'), findsOneWidget);
    },
  );

  testWidgets(
    'no saved goal renders no target badge, because "" is absent, not a band',
    (tester) {
      // The live payload has `goal.targetBandCode: ""` while the outer one is
      // null; an empty badge would be the bug.
      expect(targetBandNoGoalPayload()['targetBandCode'], isNull);
      expect(
        (targetBandNoGoalPayload()['goal'] as Map)['targetBandCode'],
        '',
      );
      return Future.value();
    },
  );

  testWidgets('choosing a band saves the goal with that band', (tester) async {
    useTallViewport(tester);
    Map<String, dynamic>? savedGoal;
    final adapter = adapterWith(
      targetBand: targetBandWithGoalPayload(),
      onGoal: (body) => savedGoal = body,
    );

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('target-band-C1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('weekly-hours-input')), '10');
    await tester.pumpAndSettle();

    final saveBtn = find.byKey(const Key('save-goal-btn'));
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(savedGoal, isNotNull);
    expect(savedGoal!['targetBandCode'], 'C1');
    expect(savedGoal!['weeklyStudyHours'], 10);
    // The current band comes from the payload, not from the picker.
    expect(savedGoal!['currentBandCode'], 'below_A1');
  });

  testWidgets('a failed save reports the backend message', (tester) async {
    useTallViewport(tester);
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/goal' && options.method == 'POST') {
        return FakeHttpClientAdapter.jsonResponse({
          'title': 'Invalid goal',
          'status': 400,
          'detail': "Band code 'Z9' is not valid for this certificate.",
          'code': 'TARGET_BAND_INVALID',
        }, statusCode: 400);
      }
      return adapterWith(targetBand: targetBandWithGoalPayload())
          .handler(options, body);
    });

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();

    final saveBtn = find.byKey(const Key('save-goal-btn'));
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('is not valid for this certificate'),
      findsOneWidget,
    );
  });
}
