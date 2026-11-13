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
            placementId:
                int.parse(state.pathParameters['placementId'] ?? '555'),
          ),
        ),
        GoRoute(
          path: '/path',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('LEARNING PATH')),
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

  Map<String, dynamic> completedPayload() => {
        'placementId': 555,
        'status': 'COMPLETED',
        'overallBand': 'B2',
        'totalScaledScore': 785,
        'cefrBand': 'B2',
        'canRetryGrading': false,
        'hasFailedGrading': false,
        'skillBreakdowns': [
          {
            'skill': 'listening',
            'band': 'B2',
            'scaledScore': 405,
            'rawScore': 82,
            'gradingStatus': 'COMPLETED',
          },
          {
            'skill': 'reading',
            'band': 'B2',
            'scaledScore': 380,
            'rawScore': 76,
            'gradingStatus': 'COMPLETED',
          },
        ],
      };

  testWidgets(
      'PENDING result polls status every 3s until COMPLETED and renders ScorePlacard + CefrBandBar',
      (tester) async {
    var statusCalls = 0;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/result/555' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'placementId': 555,
          'status': 'PENDING',
          'overallBand': '-',
          'totalScaledScore': 0,
          'cefrBand': 'A1',
          'skillBreakdowns': [],
        });
      }
      if (options.path == '/api/learner/placement/result/555/status' &&
          options.method == 'GET') {
        statusCalls += 1;
        if (statusCalls >= 2) {
          return FakeHttpClientAdapter.jsonResponse(completedPayload());
        }
        return FakeHttpClientAdapter.jsonResponse({
          'placementId': 555,
          'status': 'PENDING',
          'overallBand': '-',
          'totalScaledScore': 0,
          'cefrBand': 'A1',
          'skillBreakdowns': [],
        });
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildResultApp(adapter));
    await tester.pumpAndSettle();

    // Initially PENDING StateBlock
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.byType(ScorePlacard), findsNothing);

    // First 3s poll -> still PENDING
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(statusCalls, 1);
    expect(find.text('PENDING'), findsOneWidget);

    // Second 3s poll -> COMPLETED
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(statusCalls, 2);
    expect(find.byType(ScorePlacard), findsOneWidget);
    expect(find.byType(CefrBandBar), findsOneWidget);
    expect(find.text('785'), findsOneWidget);

    // Navigate to Learning Path CTA
    await tester.scrollUntilVisible(
      find.byKey(const Key('configure-path-cta')),
      200,
    );
    await tester.tap(find.byKey(const Key('configure-path-cta')));
    await tester.pumpAndSettle();
    expect(find.text('LEARNING PATH'), findsOneWidget);
  });

  testWidgets(
      'FAILED grading shows free retry button, calls POST .../retry, and polls until COMPLETED',
      (tester) async {
    var retryCalled = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/placement/result/555' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse({
          'placementId': 555,
          'status': 'FAILED',
          'overallBand': '-',
          'totalScaledScore': 0,
          'cefrBand': 'A1',
          'canRetryGrading': true,
          'hasFailedGrading': true,
          'skillBreakdowns': [
            {
              'skill': 'speaking',
              'band': '-',
              'scaledScore': 0,
              'rawScore': 0,
              'gradingStatus': 'FAILED',
            },
          ],
        });
      }
      if (options.path == '/api/learner/placement/result/555/retry' &&
          options.method == 'POST') {
        retryCalled = true;
        return FakeHttpClientAdapter.jsonResponse({'retried': true});
      }
      if (options.path == '/api/learner/placement/result/555/status' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(completedPayload());
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(buildResultApp(adapter));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('retry-grading-btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry-grading-btn')));
    await tester.pumpAndSettle();

    expect(retryCalled, isTrue);

    // Poll completes
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(ScorePlacard), findsOneWidget);
    expect(find.text('785'), findsOneWidget);
  });
}
