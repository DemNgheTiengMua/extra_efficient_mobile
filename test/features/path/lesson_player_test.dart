import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/path/screens/lesson_player_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';

import '../../helpers/fake_http_adapter.dart';
import 'path_fixtures.dart';

/// The lesson reader against the recorded payloads: it reads `cardId`,
/// `cardType`, `contentMarkdown` and `questionPrompt`, derives the A–D options
/// from their four named fields, submits the option **label** (which is what the
/// backend grades), and resumes at the 1-based `resumeCardIndex`.
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
          initialLocation: '/path/lessons/1',
          routes: [
            GoRoute(
              path: '/path/lessons/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return Scaffold(body: LessonPlayerScreen(lessonId: id));
              },
            ),
          ],
        ),
      ),
    );
  }

  FakeHttpClientAdapter adapterWith({
    Map<String, dynamic>? progress,
    List<String>? submissions,
    List<int>? viewedCardIds,
    String? checkFailureDetail,
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
      if (options.path == '/api/learner/lessons/1' && options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(lessonDetailPayload());
      }
      if (options.path == '/api/learner/lessons/1/progress' &&
          options.method == 'GET') {
        return FakeHttpClientAdapter.jsonResponse(
          progress ?? lessonProgressPayload(),
        );
      }
      if (options.path.endsWith('/view') && options.method == 'POST') {
        final segments = options.path.split('/');
        viewedCardIds?.add(int.parse(segments[segments.length - 2]));
        // The real endpoint answers `{success: true}`, not a progress view.
        return FakeHttpClientAdapter.jsonResponse({'success': true});
      }
      if (options.path == '/api/learner/lessons/1/cards/4/micro-check' &&
          options.method == 'POST') {
        final selected = (body as Map)['selectedOption'] as String;
        submissions?.add(selected);
        if (checkFailureDetail != null) {
          return FakeHttpClientAdapter.jsonResponse({
            'title': 'Micro-check not found',
            'status': 404,
            'detail': checkFailureDetail,
            'code': 'practice_question_not_found',
          }, statusCode: 404);
        }
        final isCorrect = selected == 'B';
        return FakeHttpClientAdapter.jsonResponse({
          'isCorrect': isCorrect,
          'correctOption': 'B',
          'explanation':
              'The time adverbial frames an action in progress, so the present '
              'continuous is required.',
          'categoryId': 1,
        });
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });
  }

  testWidgets('the rule card renders its real contentMarkdown, not a blank body', (
    tester,
  ) async {
    useTallViewport(tester);

    await tester.pumpWidget(buildApp(adapterWith()));
    await tester.pumpAndSettle();

    expect(find.text('PRESENT CONTINUOUS TENSE'), findsOneWidget);
    expect(find.text('RULE'), findsOneWidget);
    expect(
      find.text('Use am/is/are + verb-ing for something happening now.'),
      findsOneWidget,
    );
    expect(find.text('1 OF 2'), findsOneWidget);
  });

  testWidgets(
    'a micro-check card lists its A-D options with their text, and submits the '
    'label the backend grades',
    (tester) async {
      useTallViewport(tester);
      final submissions = <String>[];

      await tester.pumpWidget(
        buildApp(adapterWith(submissions: submissions)),
      );
      await tester.pumpAndSettle();

      // Advance from the rule card to the micro-check.
      await tester.tap(find.byKey(const Key('lesson-next-btn')));
      await tester.pumpAndSettle();

      expect(find.text('2 OF 2'), findsOneWidget);
      expect(find.text('CHECK YOUR UNDERSTANDING'), findsOneWidget);
      // The four options come from optionA..optionD, with their text.
      for (final label in ['A', 'B', 'C', 'D']) {
        expect(find.byKey(Key('micro-option-$label')), findsOneWidget);
      }
      expect(find.text('is evaluating'), findsOneWidget);
      expect(find.text('evaluates'), findsOneWidget);

      // A wrong answer names the correct label the graded check revealed.
      await tester.tap(find.byKey(const Key('micro-option-A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('micro-check-submit-btn')));
      await tester.pumpAndSettle();

      expect(submissions, ['A']);
      expect(find.text('TRY AGAIN'), findsOneWidget);
      expect(find.textContaining('The answer is B.'), findsOneWidget);
      // The gate holds: NEXT does nothing while the check is wrong.
      expect(find.text('2 OF 2'), findsOneWidget);

      // The right answer opens the way on.
      await tester.tap(find.byKey(const Key('micro-option-B')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('micro-check-submit-btn')));
      await tester.pumpAndSettle();

      expect(submissions, ['A', 'B']);
      expect(find.text('CORRECT'), findsOneWidget);
      expect(
        find.textContaining('The time adverbial frames an action'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed micro-check reports it instead of failing silently', (
    tester,
  ) async {
    useTallViewport(tester);

    await tester.pumpWidget(
      buildApp(
        adapterWith(checkFailureDetail: 'This card is no longer available.'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lesson-next-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('micro-option-B')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('micro-check-submit-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Could not save that'), findsOneWidget);
    expect(
      find.textContaining('This card is no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets('the reader resumes at the 1-based resumeCardIndex', (
    tester,
  ) async {
    useTallViewport(tester);

    // resumeCardIndex 2 is the second card, which is the page index 1.
    await tester.pumpWidget(
      buildApp(
        adapterWith(
          progress: {
            ...lessonProgressPayload(),
            'cardsCompleted': 2,
            'isCompleted': false,
            'lastViewedCardId': 4,
            'resumeCardIndex': 2,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 OF 2'), findsOneWidget);
  });

  testWidgets('a completed module opens on its completion state', (
    tester,
  ) async {
    useTallViewport(tester);

    await tester.pumpWidget(
      buildApp(
        adapterWith(
          progress: {
            ...lessonProgressPayload(),
            'cardsCompleted': 2,
            'isCompleted': true,
            'resumeCardIndex': 2,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LESSON COMPLETED'), findsOneWidget);
  });
}
