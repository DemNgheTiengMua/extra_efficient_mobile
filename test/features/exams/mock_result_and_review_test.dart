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

  testWidgets(
      'MockResultScreen renders ScorePlacard, CefrBandBar, raw/scaled skill splits, score delta, and AI Insight with retry',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    bool retried = false;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/attempts/902/result':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'examTitle': 'TOEIC Full Mock #1',
            'totalScaledScore': 815,
            'previousTotalScaledScore': 785,
            'scoreDelta': 30,
            'overallBand': 'B2',
            'cefrBand': 'B2',
            'skillBreakdowns': [
              {
                'skill': 'listening',
                'rawScore': 82,
                'maxRawScore': 100,
                'scaledScore': 420,
              },
              {
                'skill': 'reading',
                'rawScore': 78,
                'maxRawScore': 100,
                'scaledScore': 395,
              },
            ],
          });
        case 'GET /api/learner/insights/exam/902':
          return FakeHttpClientAdapter.jsonResponse({
            'status': retried ? 'COMPLETED' : 'FAILED',
            'narrative': retried
                ? 'Strong improvement in Part 3 inference.'
                : null,
            'errorMessage': retried ? null : 'AI timeout',
          });
        case 'POST /api/learner/insights/exam/902/retry':
          retried = true;
          return FakeHttpClientAdapter.jsonResponse({
            'status': 'COMPLETED',
            'narrative': 'Strong improvement in Part 3 inference.',
          });
        default:
          return FakeHttpClientAdapter.jsonResponse({}, statusCode: 404);
      }
    });

    await tester.pumpWidget(buildTestApp(adapter: adapter, audioAdapter: audio));
    await tester.pumpAndSettle();

    expect(find.byType(ScorePlacard), findsOneWidget);
    expect(find.byType(CefrBandBar), findsOneWidget);
    expect(find.text('815'), findsOneWidget);
    expect(find.text('+30'), findsOneWidget);
    expect(find.text('420'), findsOneWidget);
    expect(find.text('395'), findsOneWidget);
    expect(find.text('82/100 RAW'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('retry-exam-insight-btn')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('retry-exam-insight-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retry-exam-insight-btn')));
    await tester.pumpAndSettle();

    expect(retried, isTrue);
    expect(
      find.text('Strong improvement in Part 3 inference.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'MockReviewScreen filters All/Wrong/Flagged, shows wrong-answer rationale & transcript, plays audio slice, and saves question',
      (tester) async {
    final audio = FakeAudioMediaAdapter();
    int? savedQuestionId;

    final adapter = FakeHttpClientAdapter((options, body) async {
      switch ('${options.method} ${options.path}') {
        case 'GET /api/learner/attempts/902/review':
          return FakeHttpClientAdapter.jsonResponse({
            'attemptId': 902,
            'examTitle': 'TOEIC Full Mock #1',
            'questions': [
              {
                'questionId': 10,
                'index': 0,
                'skill': 'listening',
                'prompt': 'Where is the meeting held?',
                'isCorrect': false,
                'isFlagged': true,
                'selectedOptionLabel': 'A',
                'correctOptionLabel': 'B',
                'wrongOptionRationale':
                    'Option A mentions the lobby, which was cancelled.',
                'explanation': 'The speaker confirmed Room 204.',
                'transcript': 'Please move the 2 PM briefing to Room 204.',
                'audioUrl': 'https://cdn.example.com/mock-master.mp3',
                'audioStartMs': 12000,
                'audioEndMs': 24000,
              },
              {
                'questionId': 11,
                'index': 1,
                'skill': 'reading',
                'prompt': 'Choose the best conjunction.',
                'isCorrect': true,
                'isFlagged': false,
                'selectedOptionLabel': 'C',
                'correctOptionLabel': 'C',
                'explanation': 'Although introduces a contrast clause.',
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
    expect(find.text('Choose the best conjunction.'), findsOneWidget);

    // Filter WRONG
    await tester.tap(find.byKey(const Key('review-filter-wrong')));
    await tester.pumpAndSettle();
    expect(find.text('Where is the meeting held?'), findsOneWidget);
    expect(find.text('Choose the best conjunction.'), findsNothing);

    // Check rationale + transcript
    expect(
      find.text('Option A mentions the lobby, which was cancelled.'),
      findsOneWidget,
    );
    expect(
      find.text('Please move the 2 PM briefing to Room 204.'),
      findsOneWidget,
    );

    // Play audio slice
    await tester.tap(find.byKey(const Key('review-play-audio-10')));
    await tester.pumpAndSettle();
    expect(audio.lastLoadedUrl, 'https://cdn.example.com/mock-master.mp3');
    expect(audio.lastClipStart, const Duration(milliseconds: 12000));
    expect(audio.lastClipEnd, const Duration(milliseconds: 24000));

    // Save question
    await tester.tap(find.byKey(const Key('review-save-question-10')));
    await tester.pumpAndSettle();
    expect(savedQuestionId, 10);
    expect(find.text('SAVED'), findsOneWidget);
  });
}
