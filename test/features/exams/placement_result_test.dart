import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/screens/placement_result_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import 'package:extra_efficient_mobile/widgets/signage_primitives.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  Widget buildResultApp(FakeHttpClientAdapter adapter) {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final router = GoRouter(
      initialLocation: '/placement/result/555',
      routes: [
        GoRoute(
          path: '/placement/result/:placementId',
          builder: (context, state) => PlacementResultScreen(
            placementId: int.parse(
              state.pathParameters['placementId'] ?? '555',
            ),
          ),
        ),
        GoRoute(
          path: '/path',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('LEARNING PATH'))),
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

  /// Recorded `GET /api/learner/placement/result/{id}` shape. Note the empty
  /// strings for the unbanded case — this endpoint never sends null here.
  Map<String, dynamic> gradedPayload() => {
    'placementId': 555,
    'attemptId': 3,
    'certId': 1,
    'certCode': 'TOEIC',
    'examName': 'TOEIC Placement Test — Diagnostic',
    'takenAt': '2026-11-13T16:00:07Z',
    'durationMinutes': 45,
    'totalQuestions': 24,
    'totalScore': 785,
    'resultBandCode': 'B2',
    'resultBandName': 'Upper intermediate',
    'cefrBands': [],
    'skillScores': [
      {
        'skillId': 1,
        'skillCode': 'LIST',
        'skillName': 'Listening',
        'rawScore': 82,
        'totalQuestions': 100,
        'scaledScore': 405,
        'bandCode': 'B2',
      },
      {
        'skillId': 2,
        'skillCode': 'READ',
        'skillName': 'Reading',
        'rawScore': 76,
        'totalQuestions': 100,
        'scaledScore': 380,
        'bandCode': 'B2',
      },
    ],
    'weakerSkillName': 'Reading',
    'bandNote': null,
    'isAutoSubmitted': false,
    'freeResponseCount': 0,
    'gradedFreeResponseCount': 0,
    'failedFreeResponseCount': 0,
    'scoreDisplayFactor': 1,
    'isGraded': true,
  };

  /// Recorded `GET .../result/{id}/status` shape while grading: nulls, and a
  /// ready-to-print `stageDescriptor`.
  Map<String, dynamic> gradingStatusPayload({bool allocated = false}) => {
    'placementId': 555,
    'attemptId': 3,
    'isGraded': allocated,
    'freeResponseCount': 5,
    'gradedFreeResponseCount': allocated ? 5 : 1,
    'failedFreeResponseCount': 0,
    'totalScore': 340,
    'bandCode': null,
    'bandName': null,
    'skillScores': [
      {
        'skillId': 1,
        'skillCode': 'LIST',
        'skillName': 'Listening',
        'rawScore': 3,
        'totalQuestions': 10,
        'scaledScore': 130,
        'bandCode': null,
      },
    ],
    'stageDescriptor': 'Checking coherence & task achievement...',
  };

  testWidgets('PENDING polls the status endpoint and renders the real exam name, score '
      'and band once graded', (tester) async {
    var statusCalls = 0;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/result/555' &&
          options.method == 'GET') {
        // `isGraded: false` while free responses are still in flight.
        return FakeHttpClientAdapter.jsonResponse({
          ...gradedPayload(),
          'isGraded': false,
          'resultBandCode': '',
          'resultBandName': '',
          'skillScores': [
            {
              'skillId': 1,
              'skillCode': 'LIST',
              'skillName': 'Listening',
              'rawScore': 3,
              'totalQuestions': 10,
              'scaledScore': 130,
              'bandCode': '',
            },
          ],
        });
      }
      if (options.path == '/api/learner/placement/result/555/status' &&
          options.method == 'GET') {
        statusCalls += 1;
        if (statusCalls >= 2) {
          return FakeHttpClientAdapter.jsonResponse(gradedPayload());
        }
        return FakeHttpClientAdapter.jsonResponse(gradingStatusPayload());
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildResultApp(adapter));
    await tester.pumpAndSettle();

    // Pending: no score placard yet, and the backend's stage sentence is shown
    // as soon as the status endpoint supplies it.
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.byType(ScorePlacard), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(statusCalls, 1);
    expect(find.text('PENDING'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(statusCalls, 2);
    expect(find.byType(ScorePlacard), findsOneWidget);
    expect(find.byType(CefrBandBar), findsOneWidget);
    expect(find.text('785'), findsOneWidget);
    expect(
      find.textContaining('TOEIC PLACEMENT TEST — DIAGNOSTIC'),
      findsOneWidget,
    );
    expect(find.textContaining('B2'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('configure-path-cta')),
      200,
    );
    await tester.tap(find.byKey(const Key('configure-path-cta')));
    await tester.pumpAndSettle();
    expect(find.text('LEARNING PATH'), findsOneWidget);
  });

  testWidgets('a graded placement with empty band strings renders the skill '
      'badge as not yet banded rather than blank', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/result/555') {
        return FakeHttpClientAdapter.jsonResponse({
          ...gradedPayload(),
          'resultBandCode': '',
          'resultBandName': '',
          'skillScores': [
            {
              'skillId': 1,
              'skillCode': 'LIST',
              'skillName': 'Listening',
              'rawScore': 3,
              'totalQuestions': 10,
              'scaledScore': 130,
              'bandCode': '',
            },
          ],
        });
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildResultApp(adapter));
    await tester.pumpAndSettle();

    expect(find.textContaining('NOT YET BANDED'), findsWidgets);
  });

  testWidgets(
    'a failed free-response grading offers the free retry and re-polls',
    (tester) async {
      var retryCalled = false;

      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/result/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            ...gradingStatusPayload(),
            'isGraded': false,
            'failedFreeResponseCount': 2,
          });
        }
        if (options.path == '/api/learner/placement/result/555/retry' &&
            options.method == 'POST') {
          retryCalled = true;
          return FakeHttpClientAdapter.jsonResponse({'requeuedCount': 2});
        }
        if (options.path == '/api/learner/placement/result/555/status' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(gradedPayload());
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(buildResultApp(adapter));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry-grading-btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry-grading-btn')));
      await tester.pumpAndSettle();
      expect(retryCalled, isTrue);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(ScorePlacard), findsOneWidget);
      expect(find.text('785'), findsOneWidget);
    },
  );
}
