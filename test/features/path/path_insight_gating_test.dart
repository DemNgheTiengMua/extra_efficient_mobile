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

/// Insight gating on the learning-path screen: the path insight describes a
/// path, so it is asked for only when one exists, its 404 is an empty state,
/// and RETRY appears only for an insight the backend will accept a retry for.
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
          ],
        ),
      ),
    );
  }

  FakeHttpClientAdapter adapterWith({
    required Map<String, dynamic> learningPath,
    Map<String, dynamic>? insightBody,
    int insightStatus = 404,
    void Function()? onInsightRequest,
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
      if (options.path == '/api/learner/learning-path' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(learningPath);
      }
      if (options.path == '/api/learner/insights/path' &&
          options.method == 'GET') {
        onInsightRequest?.call();
        return FakeHttpClientAdapter.jsonResponse(
          insightBody ?? pathInsightNotFoundPayload(),
          statusCode: insightStatus,
        );
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });
  }

  testWidgets(
    'no active path: the path insight is never requested and no error card appears',
    (tester) async {
      useTallViewport(tester);
      var insightRequests = 0;
      final adapter = adapterWith(
        learningPath: learningPathSummaryEmptyPayload(),
        onInsightRequest: () => insightRequests++,
      );

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(insightRequests, 0);
      expect(find.text('PATH INSIGHT'), findsNothing);
      expect(find.text('Path insight unavailable'), findsNothing);
      expect(find.byKey(const Key('retry-path-insight-btn')), findsNothing);
    },
  );

  testWidgets(
    'a 404 LEARNING_PATH_NOT_FOUND is an empty state, not an error card',
    (tester) async {
      useTallViewport(tester);
      var insightRequests = 0;
      final adapter = adapterWith(
        learningPath: {
          ...learningPathSummaryEmptyPayload(),
          'hasActivePath': true,
        },
        insightStatus: 404,
        onInsightRequest: () => insightRequests++,
      );

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // The path exists, so the insight is asked for once; its 404 is silent.
      expect(insightRequests, 1);
      expect(find.text('Path insight unavailable'), findsNothing);
      expect(find.text('PATH INSIGHT'), findsNothing);
    },
  );

  testWidgets('a pending insight renders without a RETRY control', (
    tester,
  ) async {
    useTallViewport(tester);
    final adapter = adapterWith(
      learningPath: {
        ...learningPathSummaryEmptyPayload(),
        'hasActivePath': true,
      },
      insightBody: dashboardInsightPendingPayload(),
      insightStatus: 200,
    );

    await tester.pumpWidget(buildApp(adapter));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('PENDING'), findsOneWidget);
    expect(find.byKey(const Key('retry-path-insight-btn')), findsNothing);
  });

  testWidgets(
    'a failed insight offers RETRY, and the retried insight is shown',
    (tester) async {
      useTallViewport(tester);
      var retries = 0;
      var status = 'failed';
      final adapter = FakeHttpClientAdapter((options, body) async {
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
        if (options.path == '/api/learner/learning-path' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            ...learningPathSummaryEmptyPayload(),
            'hasActivePath': true,
          });
        }
        if (options.path == '/api/learner/insights/path' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'status': status,
            'narrative': status == 'failed' ? null : 'Week 1 builds grammar.',
            'failureReason': 'model timeout',
          });
        }
        if (options.path == '/api/learner/insights/path/retry' &&
            options.method == 'POST') {
          retries++;
          status = 'done';
          // The real retry endpoint answers 204 No Content.
          return FakeHttpClientAdapter.jsonResponse(null, statusCode: 204);
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(buildApp(adapter));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final retryBtn = find.byKey(const Key('retry-path-insight-btn'));
      expect(retryBtn, findsOneWidget);

      await tester.tap(retryBtn);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(retries, 1);
      expect(find.text('Week 1 builds grammar.'), findsOneWidget);
      expect(retryBtn, findsNothing);
    },
  );
}
