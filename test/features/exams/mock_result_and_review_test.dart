import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:extra_efficient_mobile/core/media/audio_media_adapter.dart';
import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';
import 'package:extra_efficient_mobile/features/exams/screens/mock_result_screen.dart';
import 'package:extra_efficient_mobile/features/exams/screens/mock_review_screen.dart';
import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import 'package:extra_efficient_mobile/widgets/signage_primitives.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  Widget buildTestApp({
    required FakeHttpClientAdapter adapter,
    required FakeAudioMediaAdapter audioAdapter,
    String initialLocation = '/exams/attempts/902/result',
  }) {
    final tokenStorage = InMemoryTokenStorage(initialToken: 'valid-jwt');
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/exams/attempts/:attemptId/result',
          builder: (context, state) => MockResultScreen(
            attemptId: int.parse(state.pathParameters['attemptId'] ?? '902'),
          ),
        ),
        GoRoute(
          path: '/exams/attempts/:attemptId/review',
          builder: (context, state) => MockReviewScreen(
            attemptId: int.parse(state.pathParameters['attemptId'] ?? '902'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        httpClientAdapterProvider.overrideWithValue(adapter),
        audioMediaAdapterProvider.overrideWithValue(audioAdapter),
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

  /// Recorded `GET /api/learner/attempts/{id}/result` shape.
  Map<String, dynamic> resultPayload() => {
    'attemptId': 902,
    'examId': 1,
    'examName': 'TOEIC Full Mock #1',
    'certId': 1,
    'certCode': 'TOEIC',
    'certName': 'TOEIC Listening & Reading',
    'status': 'graded',
    'startedAt': '2026-11-13T15:44:31Z',
    'submittedAt': '2026-11-13T16:00:07Z',
    'durationSeconds': 936,
    'isAutoSubmitted': false,
    'totalScore': 815,
    'bandCode': 'B2',
    'bandName': 'Upper intermediate',
    'skillScores': [
      {
        'skillId': 1,
        'skillCode': 'LIST',
        'skillName': 'Listening',
        'modality': 'listening',
        'rawScore': 82,
        'scaledScore': 420,
        'totalQuestions': 100,
      },
      {
        'skillId': 2,
        'skillCode': 'READ',
        'skillName': 'Reading',
        'modality': 'reading',
        'rawScore': 78,
        'scaledScore': 395,
        'totalQuestions': 100,
      },
    ],
    'previousAttemptScore': 785,
    'scoreDelta': 30,
    'freeResponseCount': 0,
    'gradedFreeResponseCount': 0,
    'failedFreeResponseCount': 0,
    'scoreDisplayFactor': 1,
  };

  testWidgets(
    'MockResultScreen shows the real exam name, total score and band, with '
    'raw/scaled splits, delta and insight retry',
    (tester) async {
      final audio = FakeAudioMediaAdapter();
      bool retried = false;

      final adapter = FakeHttpClientAdapter((options, body) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /api/learner/attempts/902/result':
            return FakeHttpClientAdapter.jsonResponse(resultPayload());
          case 'GET /api/learner/insights/exam/902':
            return FakeHttpClientAdapter.jsonResponse({
              'status': retried ? 'done' : 'failed',
              'narrative': retried
                  ? 'Strong improvement in Part 3 inference.'
                  : null,
              'failureReason': retried ? null : 'AI timeout',
            });
          case 'POST /api/learner/insights/exam/902/retry':
            retried = true;
            return FakeHttpClientAdapter.jsonResponse({
              'status': 'done',
              'narrative': 'Strong improvement in Part 3 inference.',
            });
          default:
            return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        }
      });

      await tester.pumpWidget(
        buildTestApp(adapter: adapter, audioAdapter: audio),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ScorePlacard), findsOneWidget);
      expect(find.byType(CefrBandBar), findsOneWidget);
      expect(find.text('815'), findsOneWidget);
      expect(find.textContaining('TOEIC FULL MOCK #1'), findsOneWidget);
      expect(find.textContaining('B2'), findsWidgets);
      expect(find.text('+30'), findsOneWidget);
      // Skill splits come from the backend's own scaled scores.
      expect(find.text('420'), findsOneWidget);
      expect(find.text('395'), findsOneWidget);
      expect(find.text('82/100 RAW'), findsOneWidget);
      expect(find.text('LISTENING'), findsWidgets);

      await tester.scrollUntilVisible(
        find.byKey(const Key('retry-exam-insight-btn')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('retry-exam-insight-btn')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('retry-exam-insight-btn')));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
      expect(
        find.text('Strong improvement in Part 3 inference.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a result with no band prints NOT YET BANDED instead of an '
      'empty badge', (tester) async {
    final adapter = FakeHttpClientAdapter((options, body) async {
      if (options.path == '/api/learner/attempts/902/result') {
        return FakeHttpClientAdapter.jsonResponse({
          ...resultPayload(),
          'bandCode': null,
          'bandName': null,
          'scoreDelta': null,
          'previousAttemptScore': null,
        });
      }
      if (options.path == '/api/learner/insights/exam/902') {
        return FakeHttpClientAdapter.jsonResponse({'status': 'pending'});
      }
      return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      buildTestApp(adapter: adapter, audioAdapter: FakeAudioMediaAdapter()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('NOT YET BANDED'), findsOneWidget);
    // No band means no band bar to claim a level.
    expect(find.byType(CefrBandBar), findsNothing);
  });

  testWidgets(
    'MockReviewScreen reads the correct option from the per-option flags, '
    'shows the explanation, filters, plays the slice and saves',
    (tester) async {
      final audio = FakeAudioMediaAdapter();
      int? savedQuestionId;

      final adapter = FakeHttpClientAdapter((options, body) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /api/learner/attempts/902/review':
            return FakeHttpClientAdapter.jsonResponse({
              'attemptId': 902,
              'examId': 1,
              'examName': 'TOEIC Full Mock #1',
              'certId': 1,
              'certCode': 'TOEIC',
              'certName': 'TOEIC Listening & Reading',
              'status': 'graded',
              'totalQuestions': 2,
              'answeredCount': 1,
              'correctCount': 0,
              'incorrectCount': 1,
              'blankCount': 1,
              'flaggedCount': 1,
              'questions': [
                {
                  'questionId': 10,
                  'displayOrder': 1,
                  'skillName': 'Listening',
                  'stem': 'Where is the meeting held?',
                  'explanation': 'The speaker confirmed Room 204.',
                  'transcript': 'Please move the 2 PM briefing to Room 204.',
                  'audioPath': '/audio/toeic/mock-master.mp3',
                  'audioStartMs': 12000,
                  'audioEndMs': 24000,
                  'selectedOptionId': 101,
                  'isCorrect': false,
                  'isFlagged': true,
                  'options': [
                    {
                      'optionId': 101,
                      'label': 'A',
                      'text': 'In the lobby',
                      'isCorrect': false,
                      'rationale':
                          'Option A mentions the lobby, which was cancelled.',
                    },
                    {
                      'optionId': 102,
                      'label': 'B',
                      'text': 'In Room 204',
                      'isCorrect': true,
                      'rationale': null,
                    },
                  ],
                },
                {
                  'questionId': 11,
                  'displayOrder': 2,
                  'skillName': 'Reading',
                  'stem': 'Choose the best conjunction.',
                  'explanation': 'Although introduces a contrast clause.',
                  'selectedOptionId': null,
                  'isCorrect': null,
                  'isFlagged': false,
                  'options': [
                    {
                      'optionId': 111,
                      'label': 'A',
                      'text': 'Because',
                      'isCorrect': false,
                      'rationale': null,
                    },
                    {
                      'optionId': 112,
                      'label': 'B',
                      'text': 'Although',
                      'isCorrect': true,
                      'rationale': null,
                    },
                  ],
                },
              ],
            });
          case 'POST /api/learner/saved-questions/questions/10':
            savedQuestionId = 10;
            return FakeHttpClientAdapter.jsonResponse({'saved': true});
          default:
            return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
        }
      });

      await tester.pumpWidget(
        buildTestApp(
          adapter: adapter,
          audioAdapter: audio,
          initialLocation: '/exams/attempts/902/review',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Where is the meeting held?'), findsOneWidget);

      // The correct option and its text come from the option flags.
      expect(find.text('YOURS: A · CORRECT: B'), findsOneWidget);
      expect(find.text('CORRECT ANSWER: In Room 204'), findsOneWidget);
      expect(find.text('The speaker confirmed Room 204.'), findsOneWidget);

      // Filter WRONG: the blank question has no verdict, so it is not wrong.
      await tester.tap(find.byKey(const Key('review-filter-wrong')));
      await tester.pumpAndSettle();
      expect(find.text('Where is the meeting held?'), findsOneWidget);
      expect(find.text('Choose the best conjunction.'), findsNothing);
      expect(
        find.text('Option A mentions the lobby, which was cancelled.'),
        findsOneWidget,
      );
      expect(
        find.text('Please move the 2 PM briefing to Room 204.'),
        findsOneWidget,
      );

      // The replay button reads the backend's audioPath, not a generic url.
      await tester.tap(find.byKey(const Key('review-play-audio-10')));
      await tester.pumpAndSettle();
      expect(audio.lastLoadedUrl, '/audio/toeic/mock-master.mp3');
      expect(audio.lastClipStart, const Duration(milliseconds: 12000));
      expect(audio.lastClipEnd, const Duration(milliseconds: 24000));

      await tester.tap(find.byKey(const Key('review-save-question-10')));
      await tester.pumpAndSettle();
      expect(savedQuestionId, 10);
      expect(find.text('SAVED'), findsOneWidget);

      // A blank answer is labelled as such rather than as wrong.
      await tester.tap(find.byKey(const Key('review-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('NOT ANSWERED'), findsOneWidget);
    },
  );
}
