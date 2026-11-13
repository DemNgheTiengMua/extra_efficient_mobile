import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/screens/mock_exam_room_screen.dart';
import 'package:extra_efficient_mobile/features/exams/screens/placement_exam_room_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';

import '../../helpers/fake_http_adapter.dart';

/// The reported "stuck screen with no buttons" and the terminal states that
/// replaced it.
///
/// The escape tests are the point: leaving must navigate even when the backend
/// refuses to cancel a graded or expired sitting, because that refusal is
/// exactly the state the learner is trapped in.
void main() {
  Widget buildApp({
    required FakeHttpClientAdapter adapter,
    required String initialLocation,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/placement/take/:placementId',
          builder: (context, state) => PlacementExamRoomScreen(
            placementId: int.parse(state.pathParameters['placementId'] ?? '0'),
          ),
          routes: [
            GoRoute(
              path: 'preflight',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text(
                    'PLACEMENT GATE #${state.pathParameters['placementId']}',
                  ),
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/placement',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('PLACEMENT SHEET')),
          ),
        ),
        GoRoute(
          path: '/placement/result/:placementId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('PLACEMENT RESULT #${state.pathParameters['placementId']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/exams/attempts/:attemptId',
          builder: (context, state) => MockExamRoomScreen(
            attemptId: int.parse(state.pathParameters['attemptId'] ?? '0'),
          ),
          routes: [
            GoRoute(
              path: 'preflight',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text(
                    'ATTEMPT GATE #${state.pathParameters['attemptId']}',
                  ),
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/exams/attempts/:attemptId/result',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('MOCK RESULT #${state.pathParameters['attemptId']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/exams',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('EXAMS HUB')),
          ),
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

  Map<String, dynamic> sitting({
    String status = 'in_progress',
    int questions = 2,
    Duration remaining = const Duration(minutes: 20),
    int answered = 0,
  }) => {
    'placementId': 555,
    'attemptId': 3,
    'examId': 2,
    'examName': 'TOEIC Placement Test — Diagnostic',
    'certCode': 'TOEIC',
    'status': status,
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'expiresAt': DateTime.now().toUtc().add(remaining).toIso8601String(),
    'remainingSeconds': remaining.inSeconds,
    'totalQuestions': questions,
    'answeredCount': answered,
    'flaggedCount': 0,
    'currentQuestion': _question(1),
    'navigator': <dynamic>[],
    'isAutoSubmitted': false,
    'questions': [
      for (var i = 0; i < questions; i++) _question(i + 1),
    ],
    'phases': <dynamic>[],
  };

  group('leaving a room never depends on a backend answer', () {
    testWidgets(
        'a mock attempt whose cancel is refused still navigates on EXIT',
        (tester) async {
      var cancelCalls = 0;
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/attempts/777' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 777,
            'examName': 'ETS 2024 — Test 1',
            'status': 'graded',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
            'totalQuestions': 1,
            'currentQuestion': _question(1),
            'navigator': <dynamic>[],
            'questions': [_question(1)],
          });
        }
        if (options.path == '/api/learner/attempts/777/cancel') {
          cancelCalls += 1;
          return FakeHttpClientAdapter.jsonResponse(
            {
              'title': 'Attempt not active',
              'status': 400,
              'code': 'ATTEMPT_NOT_ACTIVE',
            },
            statusCode: 400,
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/exams/attempts/777'),
      );
      await tester.pumpAndSettle();

      // EXIT is the unconditional escape and is painted from the first frame.
      await tester.tap(find.byKey(const Key('exam-exit-btn')));
      await tester.pumpAndSettle();

      expect(find.text('EXAMS HUB'), findsOneWidget);
      // Leaving is a navigation, not a transaction: it never called cancel.
      expect(cancelCalls, 0);
    });

    testWidgets(
        'the deliberate CANCEL reports its refusal and keeps the room usable',
        (tester) async {
      var cancelCalls = 0;
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/attempts/778' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 778,
            'examName': 'ETS 2024 — Test 1',
            'status': 'in_progress',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
            'totalQuestions': 1,
            'currentQuestion': _question(1),
            'navigator': <dynamic>[],
            'questions': [_question(1)],
          });
        }
        if (options.path == '/api/learner/attempts/778/cancel') {
          cancelCalls += 1;
          return FakeHttpClientAdapter.jsonResponse(
            {
              'title': 'Attempt not active',
              'status': 400,
              'code': 'ATTEMPT_NOT_ACTIVE',
            },
            statusCode: 400,
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/exams/attempts/778'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel-exam-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-cancel-btn')));
      await tester.pumpAndSettle();

      expect(cancelCalls, 1);
      // Refused, so the learner stays - but EXIT is still there.
      expect(find.text('EXAMS HUB'), findsNothing);
      expect(find.byKey(const Key('exam-exit-btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('exam-exit-btn')));
      await tester.pumpAndSettle();
      expect(find.text('EXAMS HUB'), findsOneWidget);
    });

    testWidgets('a placement abandon that is refused still lets the learner out',
        (tester) async {
      var abandonCalls = 0;
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(sitting());
        }
        if (options.path == '/api/learner/placement/take/555/abandon') {
          abandonCalls += 1;
          return FakeHttpClientAdapter.jsonResponse(
            {'status': 400, 'code': 'placement_not_active'},
            statusCode: 400,
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('exam-abandon-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-abandon-btn')));
      await tester.pumpAndSettle();

      expect(abandonCalls, 1);
      expect(find.text('EXAMS HUB'), findsNothing);

      await tester.tap(find.byKey(const Key('exam-exit-btn')));
      await tester.pumpAndSettle();
      expect(find.text('EXAMS HUB'), findsOneWidget);
    });
  });

  group('a sitting that cannot be read shows a terminal state with a way out',
      () {
    testWidgets('a submission already over routes to the placement result',
        (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(
            sitting(status: 'done', questions: 29),
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      expect(find.text('This sitting is over'), findsOneWidget);
      expect(find.byKey(const Key('exam-terminal-leave-btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('exam-terminal-primary-btn')));
      await tester.pumpAndSettle();
      expect(find.text('PLACEMENT RESULT #555'), findsOneWidget);
    });

    testWidgets('an abandoned sitting offers the hub', (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(
            sitting(status: 'abandoned'),
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      expect(find.text('This sitting was abandoned'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam-terminal-primary-btn')));
      await tester.pumpAndSettle();
      expect(find.text('EXAMS HUB'), findsOneWidget);
    });

    testWidgets('a sitting with no questions is terminal, not a blank room',
        (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(sitting(questions: 0));
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      expect(find.text('This sitting has no questions'), findsOneWidget);
      expect(find.byKey(const Key('exam-terminal-leave-btn')), findsOneWidget);
    });

    testWidgets(
        'a 400 placement_not_active on read is a normal end, not an error card',
        (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(
            {
              'title': 'Placement test not active',
              'status': 400,
              'detail': 'This exam attempt is no longer in progress.',
              'code': 'placement_not_active',
            },
            statusCode: 400,
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      expect(find.text('This sitting is over'), findsOneWidget);
      expect(find.text('Exam room error'), findsNothing);
    });
  });

  group('every door passes the device gate', () {
    testWidgets('the room redirects to the gate on preflight_required',
        (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          // Exactly what the backend answers before the gate has passed.
          return FakeHttpClientAdapter.jsonResponse(
            {
              'title': 'Preflight verification required',
              'status': 400,
              'code': 'preflight_required',
            },
            statusCode: 400,
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      // The room cannot open the sitting, so it hands over to the one gate.
      expect(find.text('PLACEMENT GATE #555'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Exam room error'), findsNothing);
    });

    testWidgets('a sitting whose read fails still offers a way out',
        (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        return FakeHttpClientAdapter.jsonResponse(
          {'status': 500, 'code': 'UNEXPECTED'},
          statusCode: 500,
        );
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exam-terminal-leave-btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam-terminal-leave-btn')));
      await tester.pumpAndSettle();
      expect(find.text('EXAMS HUB'), findsOneWidget);
    });
  });

  group('resume shows the progress the server holds', () {
    testWidgets('a resumed placement shows how many questions were answered',
        (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(
            sitting(questions: 29, answered: 24),
          );
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-answered-banner')), findsOneWidget);
      expect(find.textContaining('24 of 29'), findsOneWidget);
    });

    testWidgets('a fresh sitting shows no resume banner', (tester) async {
      final adapter = FakeHttpClientAdapter((options, body) async {
        if (options.path == '/api/learner/placement/take/555' &&
            options.method == 'GET') {
          return FakeHttpClientAdapter.jsonResponse(sitting(questions: 29));
        }
        return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      await tester.pumpWidget(
        buildApp(adapter: adapter, initialLocation: '/placement/take/555'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-answered-banner')), findsNothing);
      expect(find.textContaining('Q1/29'), findsOneWidget);
    });
  });
}

Map<String, dynamic> _question(int id) => {
  'questionId': id,
  'displayOrder': id,
  'totalQuestions': 2,
  'sectionId': 1,
  'sectionCode': 'P1',
  'sectionName': 'Photographs',
  'skillCode': 'LIST',
  'skillName': 'Listening',
  'modality': 'listening',
  'stem': 'Look at the photograph.',
  'imagePath': '/img/part1-sample.svg',
  'audioPath': '/audio/toeic/placement-p1.mp3',
  'audioStartMs': null,
  'audioEndMs': null,
  'options': [
    {'optionId': id * 10, 'label': 'A', 'text': 'A woman is writing.'},
    {'optionId': id * 10 + 1, 'label': 'B', 'text': 'Some chairs are stacked.'},
  ],
  'selectedOptionId': null,
  'isFlagged': false,
  'questionType': 'mcq',
};
